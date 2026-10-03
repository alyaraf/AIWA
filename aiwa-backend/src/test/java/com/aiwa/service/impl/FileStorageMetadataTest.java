package com.aiwa.service.impl;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.CRC32;

import static org.assertj.core.api.Assertions.assertThat;

/** CR-14: public images lose their EXIF/GPS and text chunks, are stored upright and bounded; private files are untouched. */
class FileStorageMetadataTest {

    private static final String GPS = "GPS-LAT-30.0444N-LON-31.2357E";

    @TempDir Path tmp;
    private final FileStorageServiceImpl storage = new FileStorageServiceImpl();

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(storage, "publicPath", tmp.resolve("public").toString());
        ReflectionTestUtils.setField(storage, "privatePath", tmp.resolve("private").toString());
    }

    @Test
    void jpegGpsExifIsDroppedAndTheImageStillDecodes() throws Exception {
        byte[] withExif = jpegWithExif(split(40, 20), 1);
        assertThat(contains(withExif, GPS)).isTrue(); // sanity: the fixture really carries the location

        for (String folder : new String[]{"avatars", "gallery"}) {
            byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.jpg", "image/jpeg", withExif), folder));
            assertThat(hasApp1(stored)).as(folder + " has no APP1 segment").isFalse();
            assertThat(contains(stored, GPS)).isFalse();
            assertThat(contains(stored, "Exif")).isFalse();
            BufferedImage img = ImageIO.read(new ByteArrayInputStream(stored));
            assertThat(img).isNotNull();
            assertThat(img.getWidth()).isEqualTo(40);
        }
    }

    @Test
    void pngTextChunksAreDropped() throws Exception {
        byte[] withText = pngWithText(split(30, 30), "Comment", GPS);
        assertThat(contains(withText, GPS)).isTrue();

        byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.png", "image/png", withText)));
        assertThat(contains(stored, GPS)).isFalse();
        assertThat(contains(stored, "tEXt")).isFalse();
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(stored));
        assertThat(img).isNotNull();
        assertThat(img.getHeight()).isEqualTo(30);
    }

    @Test
    void exifOrientation6IsAppliedSoThePhotoIsStoredUpright() throws Exception {
        // 40x20, left half red, right half blue, tagged "rotate 90 clockwise to display".
        byte[] stored = readPublic(storage.storePublic(
                new MockMultipartFile("i", "a.jpg", "image/jpeg", jpegWithExif(split(40, 20), 6)), "avatars"));
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(stored));
        assertThat(img.getWidth()).isEqualTo(20);
        assertThat(img.getHeight()).isEqualTo(40);
        // Rotated clockwise: the left (red) half is now the top, the right (blue) half the bottom.
        assertThat(new Color(img.getRGB(10, 5)).getRed()).isGreaterThan(150);
        assertThat(new Color(img.getRGB(10, 35)).getBlue()).isGreaterThan(150);
    }

    @Test
    void oversizedImagesAreScaledDownToTheConfiguredLongestSide() throws Exception {
        byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.png", "image/png", pngWithText(split(3000, 1000), "k", "v"))));
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(stored));
        assertThat(img.getWidth()).isEqualTo(2048);
        assertThat(img.getHeight()).isBetween(682, 684);
    }

    @Test
    void anImageImageIoCannotDecodeIsStoredAsIsNotRejected() {
        byte[] webpHeader = "RIFF\0\0\0\0WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);
        byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.webp", "image/webp", webpHeader)));
        assertThat(stored).isEqualTo(webpHeader);
    }

    @Test
    void privateDocumentsAreStoredByteIdentical() throws Exception {
        byte[] id = jpegWithExif(split(40, 20), 6);
        String stored = storage.storePrivate(new MockMultipartFile("f", "id.jpg", "image/jpeg", id), "national-id");
        assertThat(Files.readAllBytes(storage.resolvePrivate(stored).orElseThrow())).isEqualTo(id);
    }

    // ── fixtures ──────────────────────────────────────────────────────────────

    private byte[] readPublic(String url) {
        try {
            return Files.readAllBytes(tmp.resolve("public").resolve(url.substring("/files/public/".length())));
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Left half red, right half blue. */
    private static BufferedImage split(int w, int h) {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        g.setColor(Color.RED);
        g.fillRect(0, 0, w / 2, h);
        g.setColor(Color.BLUE);
        g.fillRect(w / 2, 0, w - w / 2, h);
        g.dispose();
        return img;
    }

    private static byte[] encode(BufferedImage img, String format) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, format, out);
        return out.toByteArray();
    }

    /** A JPEG with an EXIF APP1 segment: orientation tag plus a GPS block (the location text). */
    private static byte[] jpegWithExif(BufferedImage img, int orientation) throws IOException {
        byte[] gps = (GPS + "\0").getBytes(StandardCharsets.US_ASCII);
        ByteBuffer tiff = ByteBuffer.allocate(8 + 2 + 2 * 12 + 4 + gps.length); // big-endian
        tiff.put((byte) 'M').put((byte) 'M').putShort((short) 42).putInt(8);
        tiff.putShort((short) 2);
        tiff.putShort((short) 0x0112).putShort((short) 3).putInt(1).putShort((short) orientation).putShort((short) 0);
        tiff.putShort((short) 0x8825).putShort((short) 4).putInt(1).putInt(8 + 2 + 24 + 4); // GPS "IFD" = the text
        tiff.putInt(0).put(gps);

        ByteArrayOutputStream app1 = new ByteArrayOutputStream();
        app1.write(0xFF);
        app1.write(0xE1);
        int len = 2 + 6 + tiff.capacity();
        app1.write(len >> 8);
        app1.write(len & 0xFF);
        app1.write("Exif\0\0".getBytes(StandardCharsets.US_ASCII));
        app1.write(tiff.array());

        byte[] jpeg = encode(img, "jpeg");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(jpeg, 0, 2); // SOI
        out.write(app1.toByteArray());
        out.write(jpeg, 2, jpeg.length - 2);
        return out.toByteArray();
    }

    /** A PNG with a tEXt chunk right after IHDR. */
    private static byte[] pngWithText(BufferedImage img, String key, String value) throws IOException {
        byte[] png = encode(img, "png");
        byte[] data = (key + "\0" + value).getBytes(StandardCharsets.ISO_8859_1);
        byte[] type = "tEXt".getBytes(StandardCharsets.US_ASCII);
        CRC32 crc = new CRC32();
        crc.update(type);
        crc.update(data);
        ByteBuffer chunk = ByteBuffer.allocate(12 + data.length);
        chunk.putInt(data.length).put(type).put(data).putInt((int) crc.getValue());
        int afterIhdr = 8 + 12 + 13;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(png, 0, afterIhdr);
        out.write(chunk.array());
        out.write(png, afterIhdr, png.length - afterIhdr);
        return out.toByteArray();
    }

    private static boolean contains(byte[] hay, String needle) {
        return new String(hay, StandardCharsets.ISO_8859_1).contains(needle);
    }

    /** True when any segment before the scan data is an APP1 (0xFFE1). */
    private static boolean hasApp1(byte[] jpeg) {
        int i = 2;
        while (i + 4 <= jpeg.length && (jpeg[i] & 0xFF) == 0xFF) {
            int marker = jpeg[i + 1] & 0xFF;
            if (marker == 0xE1) return true;
            if (marker == 0xDA) return false;
            i += 2 + (((jpeg[i + 2] & 0xFF) << 8) | (jpeg[i + 3] & 0xFF));
        }
        return false;
    }
}
