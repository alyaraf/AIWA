package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.exception.TooManyRequestsException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * CR-14 follow-up: a progressive JPEG keeps the whole image's coefficients in native memory while it is decoded, so
 * the 200 Mpx ceiling does not bound it. Progressive frames get a lower ceiling, and only a few decodes run at once.
 */
class FileStorageDecodeLimitsTest {

    @TempDir Path tmp;
    private final FileStorageServiceImpl storage = new FileStorageServiceImpl();

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(storage, "publicPath", tmp.resolve("public").toString());
        ReflectionTestUtils.setField(storage, "privatePath", tmp.resolve("private").toString());
    }

    @Test
    void aProgressiveJpegDeclaring14142SquaredPixelsIsRefusedQuicklyAndNothingIsStored() throws Exception {
        byte[] bomb = progressiveJpeg(8, 8);
        patchSize(bomb, 0xC2, 14142, 14142); // 199,996,164 px: under the 200 Mpx ceiling, over the progressive one
        // warm up ImageIO so the timing below measures the guard, not class loading
        storage.storePublic(new MockMultipartFile("w", "w.jpg", "image/jpeg", progressiveJpeg(4, 4)), "warm");
        Files.walk(tmp.resolve("public")).sorted(java.util.Comparator.reverseOrder()).forEach(p -> p.toFile().delete());

        long t0 = System.nanoTime();
        assertThatThrownBy(() -> storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", bomb), "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
        assertThat((System.nanoTime() - t0) / 1_000_000).as("refused in ms").isLessThan(1000);
        assertThat(Files.exists(tmp.resolve("public"))).as("nothing stored").isFalse();
    }

    @Test
    void aJunkByteBetweenSegmentsDoesNotHideAProgressiveBomb() throws Exception {
        // H-3 (audit 2026-10-03): one byte after APP0 used to end the marker walk with "not progressive".
        byte[] bomb = progressiveJpeg(8, 8);
        patchSize(bomb, 0xC2, 14142, 14142);
        byte[] withJunk = insertAfterFirstSegment(bomb, (byte) 0x00);
        assertThat(FileStorageServiceImpl.progressivePixels(withJunk)).isEqualTo(14142L * 14142L);
        byte[] withJunkRun = insertAfterFirstSegment(bomb, (byte) 0x12, (byte) 0x34, (byte) 0xFF, (byte) 0x00);
        assertThat(FileStorageServiceImpl.progressivePixels(withJunkRun)).isEqualTo(14142L * 14142L);

        assertThatThrownBy(() -> storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", withJunk), "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
        assertThat(Files.exists(tmp.resolve("public"))).as("nothing stored").isFalse();
    }

    @Test
    void theDecoderMetadataGuardRefusesAProgressiveFrameTheMarkerWalkMissed() throws Exception {
        byte[] photo = progressiveJpeg(64, 64);
        try (var in = ImageIO.createImageInputStream(new ByteArrayInputStream(photo))) {
            var reader = ImageIO.getImageReaders(in).next();
            reader.setInput(in, true, true);
            assertThat(FileStorageServiceImpl.isBaselineJpeg(reader)).isFalse();
            reader.dispose();
        }
        try (var in = ImageIO.createImageInputStream(new ByteArrayInputStream(baselineJpeg(64, 64)))) {
            var reader = ImageIO.getImageReaders(in).next();
            reader.setInput(in, true, true);
            assertThat(FileStorageServiceImpl.isBaselineJpeg(reader)).isTrue();
            reader.dispose();
        }
    }

    @Test
    void aProgressivePhotoUnderTheCeilingStillStores() throws Exception {
        byte[] photo = progressiveJpeg(640, 480);
        String url = storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", photo), "avatars");

        BufferedImage stored = ImageIO.read(new ByteArrayInputStream(
                Files.readAllBytes(tmp.resolve("public").resolve(url.substring("/files/public/".length())))));
        assertThat(stored.getWidth()).isEqualTo(640);
        assertThat(stored.getHeight()).isEqualTo(480);
    }

    @Test
    void theProgressiveCeilingIsConfigurable() throws Exception {
        ReflectionTestUtils.setField(storage, "maxProgressivePixels", 100L);
        assertThatThrownBy(() -> storage.storePublic(
                new MockMultipartFile("i", "a.jpg", "image/jpeg", progressiveJpeg(20, 20)), "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
        // a plain (baseline) JPEG of the same size is not progressive: the lower ceiling does not apply
        storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", baselineJpeg(20, 20)), "avatars");
    }

    @Test
    void onlyTheConfiguredNumberOfDecodesRunAtOnceAndTheNextOneIsTurnedAway() throws Exception {
        storage.setPublicDecodeConcurrency(2);
        ReflectionTestUtils.setField(storage, "decodeWaitMillis", 150L);
        CountDownLatch inside = new CountDownLatch(2), release = new CountDownLatch(1);
        Thread[] holders = new Thread[2];
        for (int i = 0; i < holders.length; i++) {
            holders[i] = new Thread(() -> {
                try {
                    storage.withDecodeSlot(() -> {
                        inside.countDown();
                        try {
                            release.await(10, TimeUnit.SECONDS);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                        }
                        return null;
                    });
                } catch (IOException e) {
                    throw new IllegalStateException(e);
                }
            });
            holders[i].start();
        }
        assertThat(inside.await(5, TimeUnit.SECONDS)).as("both decodes are running").isTrue();

        MockMultipartFile third = new MockMultipartFile("i", "a.jpg", "image/jpeg", baselineJpeg(20, 20));
        assertThatThrownBy(() -> storage.storePublic(third, "avatars"))
                .isInstanceOf(TooManyRequestsException.class).hasMessage("error.too_many_requests");
        assertThat(Files.exists(tmp.resolve("public"))).as("nothing stored for the refused one").isFalse();

        release.countDown();
        for (Thread h : holders) h.join(5000);
        // the slots come back: the same upload now goes through
        storage.storePublic(third, "avatars");
        assertThat(Files.list(tmp.resolve("public").resolve("avatars")).count()).isEqualTo(1);
    }

    // ── fixtures ──────────────────────────────────────────────────────────────

    private static BufferedImage photo(int w, int h) {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        for (int y = 0; y < h; y++) {
            g.setColor(new Color(y * 255 / Math.max(1, h - 1), 80, 200 - y * 150 / Math.max(1, h - 1)));
            g.drawLine(0, y, w, y);
        }
        g.dispose();
        return img;
    }

    private static byte[] baselineJpeg(int w, int h) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(photo(w, h), "jpeg", out);
        return out.toByteArray();
    }

    private static byte[] progressiveJpeg(int w, int h) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ImageWriteParam param = writer.getDefaultWriteParam();
        param.setProgressiveMode(ImageWriteParam.MODE_DEFAULT);
        try (ImageOutputStream ios = ImageIO.createImageOutputStream(out)) {
            writer.setOutput(ios);
            writer.write(null, new IIOImage(photo(w, h), null, null), param);
        } finally {
            writer.dispose();
        }
        byte[] jpeg = out.toByteArray();
        assertThat(findSof(jpeg)).as("fixture really is progressive (SOF2)").isGreaterThan(0);
        return jpeg;
    }

    /** Offset of the SOF2 marker's 0xFF, or -1. */
    private static int findSof(byte[] jpeg) {
        for (int i = 2; i + 9 < jpeg.length; i++) {
            if ((jpeg[i] & 0xFF) == 0xFF && (jpeg[i + 1] & 0xFF) == 0xC2) return i;
        }
        return -1;
    }

    /** Copy of {@code jpeg} with {@code junk} inserted right after the first segment that follows SOI (APP0). */
    private static byte[] insertAfterFirstSegment(byte[] jpeg, byte... junk) {
        int len = ((jpeg[4] & 0xFF) << 8) | (jpeg[5] & 0xFF);
        int at = 4 + len;
        byte[] out = new byte[jpeg.length + junk.length];
        System.arraycopy(jpeg, 0, out, 0, at);
        System.arraycopy(junk, 0, out, at, junk.length);
        System.arraycopy(jpeg, at, out, at + junk.length, jpeg.length - at);
        return out;
    }

    /** Rewrites the declared height and width of the SOFn frame header. */
    private static void patchSize(byte[] jpeg, int marker, int width, int height) {
        for (int i = 2; i + 9 < jpeg.length; i++) {
            if ((jpeg[i] & 0xFF) == 0xFF && (jpeg[i + 1] & 0xFF) == marker) {
                jpeg[i + 5] = (byte) (height >> 8); jpeg[i + 6] = (byte) height;
                jpeg[i + 7] = (byte) (width >> 8); jpeg[i + 8] = (byte) width;
                return;
            }
        }
        throw new IllegalStateException("no SOF marker " + Integer.toHexString(marker));
    }

    // ---- B-01 (audit round 3): scanline allocation is bounded before decoding -------------------------------

    @Test
    void aSkinnyPngHeaderDeclaring20MillionColumnsIsRefusedBeforeAnyDecodeAllocation() {
        byte[] header = pngHeaderOnly(20_000_000, 1);
        assertThatThrownBy(() -> storage.storePublic(new MockMultipartFile("i", "a.png", "image/png", header), "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
        assertThat(Files.exists(tmp.resolve("public"))).as("nothing stored").isFalse();
    }

    @Test
    void anImageWiderThanTheDimensionCeilingIsRefusedEvenWhenItsAreaIsSmall() {
        byte[] header = pngHeaderOnly(16_385, 1);
        assertThatThrownBy(() -> storage.storePublic(new MockMultipartFile("i", "a.png", "image/png", header), "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
    }

    @Test
    void theWorkingMemoryEstimateGrowsWithWidthAndShrinksWithSubsampling() {
        assertThat(FileStorageServiceImpl.estimatedDecodeBytes(20_000_000, 1, 9766)).isGreaterThan(128L * 1024 * 1024);
        assertThat(FileStorageServiceImpl.estimatedDecodeBytes(4000, 3000, 1)).isLessThan(128L * 1024 * 1024);
        assertThat(FileStorageServiceImpl.estimatedDecodeBytes(14_000, 14_000, 6))
                .isLessThan(FileStorageServiceImpl.estimatedDecodeBytes(14_000, 14_000, 1));
    }

    @Test
    void anOrdinaryLargePhotoStillStores() throws Exception {
        byte[] jpg = baselineJpeg(3000, 2000);
        assertThat(storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", jpg), "avatars")).isNotBlank();
    }

    /** Signature + a valid IHDR + IEND only (no pixel data), like the 66-byte probe in the audit. */
    private static byte[] pngHeaderOnly(int width, int height) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.writeBytes(new byte[]{(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A});
        byte[] ihdr = new byte[13];
        putInt(ihdr, 0, width);
        putInt(ihdr, 4, height);
        ihdr[8] = 8;  // bit depth
        ihdr[9] = 6;  // RGBA
        chunk(out, "IHDR", ihdr);
        chunk(out, "IEND", new byte[0]);
        return out.toByteArray();
    }

    private static void putInt(byte[] b, int at, int v) {
        b[at] = (byte) (v >>> 24); b[at + 1] = (byte) (v >>> 16); b[at + 2] = (byte) (v >>> 8); b[at + 3] = (byte) v;
    }

    private static void chunk(ByteArrayOutputStream out, String type, byte[] data) {
        byte[] len = new byte[4];
        putInt(len, 0, data.length);
        out.writeBytes(len);
        byte[] t = type.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        out.writeBytes(t);
        out.writeBytes(data);
        java.util.zip.CRC32 crc = new java.util.zip.CRC32();
        crc.update(t);
        crc.update(data);
        byte[] c = new byte[4];
        putInt(c, 0, (int) crc.getValue());
        out.writeBytes(c);
    }
}
