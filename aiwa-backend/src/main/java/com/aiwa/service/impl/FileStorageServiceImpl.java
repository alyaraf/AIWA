package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.*;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Local-disk storage for uploads.
 *
 * <ul>
 *   <li>Public images (gallery, avatars) are returned as a URL path —
 *       {@code /files/public/<folder>/<uuid>.<ext>} — relative to the API base
 *       ({@code /api}). {@link com.aiwa.config.StaticResourceConfig} serves that
 *       prefix and SecurityConfig permits GET on it, so image loaders need no token.</li>
 *   <li>Private documents (national ID, selfie) are returned as a storage path and
 *       only ever streamed by the admin document endpoint.</li>
 * </ul>
 *
 * The file type is decided by the bytes, not by the client: the content must
 * start with a JPEG/PNG/WebP signature, and the stored extension comes from that
 * type — never from the uploaded file name — so nothing but an image can ever be
 * served back from the public folder.
 */
@Slf4j
@Service
public class FileStorageServiceImpl {

    /** Prefix (under the API context path) that public files are served from. */
    public static final String PUBLIC_URL_PREFIX = "/files/public/";

    private static final Map<String, String> EXTENSION_BY_TYPE =
            Map.of("image/jpeg", "jpg", "image/png", "png", "image/webp", "webp");
    private static final long MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

    @Value("${aiwa.storage.public-path:uploads/public}")
    private String publicPath;

    @Value("${aiwa.storage.private-path:uploads/private}")
    private String privatePath;

    /** Store a public gallery image; returns its public URL path. */
    public String storePublic(MultipartFile file) {
        return storePublic(file, "gallery");
    }

    /** Store a public image in {@code folder} (e.g. "gallery", "avatars"); returns its public URL path. */
    public String storePublic(MultipartFile file, String folder) {
        String ext = validate(file);
        String filename = store(file, publicPath, folder, ext);
        return PUBLIC_URL_PREFIX + folder + "/" + filename;
    }

    /**
     * Store a private verification document — NOT exposed via public URL.
     * Returns the storage path ("uploads/private/&lt;sub&gt;/&lt;file&gt;").
     */
    public String storePrivate(MultipartFile file, String subfolder) {
        String ext = validate(file);
        String filename = store(file, privatePath, subfolder, ext);
        return privatePath + "/" + subfolder + "/" + filename;
    }

    /** Delete a public file given the URL path {@link #storePublic} returned. */
    public void deletePublic(String publicUrl) {
        toPublicFile(publicUrl).ifPresent(this::deleteQuietly);
    }

    public void deletePrivate(String storedPath) {
        resolvePrivate(storedPath).ifPresent(this::deleteQuietly);
    }

    /**
     * Resolve a stored private path to a file that is guaranteed to sit inside the
     * private root. Anything that escapes it ("../"), or points elsewhere, is empty.
     */
    public Optional<Path> resolvePrivate(String storedPath) {
        if (storedPath == null || storedPath.isBlank()) return Optional.empty();
        Path root = Paths.get(privatePath).toAbsolutePath().normalize();
        String normalized = storedPath.replace('\\', '/');
        String rootPrefix = privatePath.replace('\\', '/');
        String relative = normalized.startsWith(rootPrefix + "/")
                ? normalized.substring(rootPrefix.length() + 1) : normalized;
        try {
            Path candidate = root.resolve(relative).normalize();
            return candidate.startsWith(root) ? Optional.of(candidate) : Optional.empty();
        } catch (InvalidPathException e) {
            return Optional.empty();
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    /** @return the extension to store under, derived from the verified content. */
    private String validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("upload.error.empty");
        }
        if (file.getSize() > MAX_FILE_SIZE_BYTES) {
            throw new BusinessException("upload.error.too_large");
        }
        String declared = file.getContentType();
        if (declared == null || !EXTENSION_BY_TYPE.containsKey(declared)) {
            throw new BusinessException("upload.error.invalid_type");
        }
        String sniffed = sniffImageType(file);
        if (sniffed == null) {
            throw new BusinessException("upload.error.invalid_type");
        }
        return EXTENSION_BY_TYPE.get(sniffed);
    }

    /** Returns the image MIME type from the file's magic bytes, or null when it isn't JPEG/PNG/WebP. */
    static String sniffImageType(MultipartFile file) {
        byte[] head = new byte[12];
        int n;
        try (InputStream in = file.getInputStream()) {
            n = in.readNBytes(head, 0, head.length);
        } catch (IOException e) {
            return null;
        }
        if (n >= 3 && (head[0] & 0xFF) == 0xFF && (head[1] & 0xFF) == 0xD8 && (head[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (n >= 8 && (head[0] & 0xFF) == 0x89 && head[1] == 'P' && head[2] == 'N' && head[3] == 'G'
                && head[4] == 0x0D && head[5] == 0x0A && head[6] == 0x1A && head[7] == 0x0A) {
            return "image/png";
        }
        if (n >= 12 && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P') {
            return "image/webp";
        }
        return null;
    }

    private String store(MultipartFile file, String basePath, String subfolder, String ext) {
        String filename = UUID.randomUUID() + "." + ext;
        Path dir = Paths.get(basePath, subfolder);
        try {
            Files.createDirectories(dir);
            Path dest = dir.resolve(filename);
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, dest, StandardCopyOption.REPLACE_EXISTING);
            }
            return filename;
        } catch (IOException e) {
            log.error("Failed to store file", e);
            throw new BusinessException("upload.error.storage_failed");
        }
    }

    private Optional<Path> toPublicFile(String publicUrl) {
        if (publicUrl == null) return Optional.empty();
        String p = publicUrl.replace('\\', '/');
        int idx = p.indexOf(PUBLIC_URL_PREFIX);
        String relative;
        if (idx >= 0) {
            relative = p.substring(idx + PUBLIC_URL_PREFIX.length());
        } else {
            // Rows written before V13 stored the disk path ("uploads/public/gallery/x.jpg").
            String legacyRoot = publicPath.replace('\\', '/') + "/";
            if (!p.startsWith(legacyRoot)) return Optional.empty();
            relative = p.substring(legacyRoot.length());
        }
        Path root = Paths.get(publicPath).toAbsolutePath().normalize();
        try {
            Path candidate = root.resolve(relative).normalize();
            return candidate.startsWith(root) ? Optional.of(candidate) : Optional.empty();
        } catch (InvalidPathException e) {
            return Optional.empty();
        }
    }

    private void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException e) {
            log.warn("Could not delete file: {}", path);
        }
    }
}
