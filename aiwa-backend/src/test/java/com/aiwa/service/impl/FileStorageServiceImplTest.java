package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FileStorageServiceImplTest {

    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0};

    @TempDir Path tmp;
    private final FileStorageServiceImpl storage = new FileStorageServiceImpl();

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(storage, "publicPath", tmp.resolve("public").toString());
        ReflectionTestUtils.setField(storage, "privatePath", tmp.resolve("private").toString());
    }

    @Test
    void publicUploadReturnsAServableUrlWithAnExtensionFromTheContent() {
        // Client claims .html; the stored file is .png because the bytes are PNG (BE-1 + XSS guard).
        String url = storage.storePublic(new MockMultipartFile("image", "x.html", "image/png", PNG));
        assertThat(url).startsWith("/files/public/gallery/").endsWith(".png");
        String name = url.substring(url.lastIndexOf('/') + 1);
        assertThat(Files.exists(tmp.resolve("public").resolve("gallery").resolve(name))).isTrue();

        storage.deletePublic(url);
        assertThat(Files.exists(tmp.resolve("public").resolve("gallery").resolve(name))).isFalse();
    }

    @Test
    void privateDocumentsAreEncryptedOnDiskWhenAKeyIsSetAndReadBackIntact() throws Exception {
        // AU-08 / M-3: an ID photo is not readable from a copy of the uploads volume.
        ReflectionTestUtils.setField(storage, "privateCipher", new com.aiwa.util.PrivateFileCipher(
                java.util.Base64.getEncoder().encodeToString(new byte[32])));
        String stored = storage.storePrivate(new MockMultipartFile("id", "id.png", "image/png", PNG), "11");
        Path onDisk = storage.resolvePrivate(stored).orElseThrow();

        assertThat(Files.readAllBytes(onDisk)).isNotEqualTo(PNG);
        assertThat(new String(Files.readAllBytes(onDisk), java.nio.charset.StandardCharsets.ISO_8859_1)).startsWith("AIWAENC1");
        assertThat(storage.readPrivate(onDisk)).isEqualTo(PNG);
        // Public images are never encrypted: browsers load them directly.
        String pub = storage.storePublic(new MockMultipartFile("image", "x.png", "image/png", PNG));
        assertThat(Files.readAllBytes(tmp.resolve("public").resolve(pub.substring("/files/public/".length())))).isNotEmpty();
    }

    @Test
    void htmlDisguisedAsAnImageIsRejected() {
        assertThatThrownBy(() -> storage.storePublic(
                new MockMultipartFile("image", "a.png", "image/png", "<html></html>".getBytes())))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.invalid_type");
    }

    @Test
    void jpegIsStoredAsJpg() {
        assertThat(storage.storePublic(new MockMultipartFile("image", "a", "image/jpeg", JPEG), "avatars"))
                .startsWith("/files/public/avatars/").endsWith(".jpg");
    }

    @Test
    void privatePathsCannotEscapeTheirRoot() {
        String stored = storage.storePrivate(new MockMultipartFile("f", "id.jpg", "image/jpeg", JPEG), "national-id");
        assertThat(storage.resolvePrivate(stored)).isPresent();
        assertThat(storage.resolvePrivate(tmp.resolve("private") + "/../../etc/passwd")).isEmpty();
        assertThat(storage.resolvePrivate("../../etc/passwd")).isEmpty();
        assertThat(storage.resolvePrivate(null)).isEmpty();
    }

    @Test
    void deletingAPublicUrlOutsideTheRootIsIgnored() {
        storage.deletePublic("/files/public/../../pom.xml"); // must not throw or touch anything
        assertThat(Files.exists(Path.of("pom.xml"))).isTrue();
    }
}
