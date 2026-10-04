package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
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
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.CRC32;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

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

    // ── decode bomb: refused from the declared size, before any pixel is decoded ──

    @Test
    void aJpegDeclaringMoreThanThePixelCeilingIsRefusedQuicklyAndNothingIsStored() throws Exception {
        byte[] bomb = encode(split(8, 8), "jpeg");
        for (int i = 2; i + 9 < bomb.length; i++) { // patch SOF0 height/width to 46340 x 46340 (2.1 Gpx)
            if ((bomb[i] & 0xFF) == 0xFF && (bomb[i + 1] & 0xFF) == 0xC0) {
                bomb[i + 5] = (byte) 0xB5; bomb[i + 6] = 0x04;
                bomb[i + 7] = (byte) 0xB5; bomb[i + 8] = 0x04;
                break;
            }
        }
        assertRefusedQuickly(new MockMultipartFile("i", "a.jpg", "image/jpeg", bomb));
    }

    @Test
    void aPngDeclaringMoreThanThePixelCeilingIsRefusedQuicklyAndNothingIsStored() throws Exception {
        byte[] bomb = encode(split(8, 8), "png");
        ByteBuffer ihdr = ByteBuffer.wrap(bomb); // signature(8) + length(4) + "IHDR"(4) + width + height
        ihdr.putInt(16, 30000).putInt(20, 30000);
        CRC32 crc = new CRC32();
        crc.update(bomb, 12, 17); // type + 13 data bytes
        ihdr.putInt(29, (int) crc.getValue());
        assertRefusedQuickly(new MockMultipartFile("i", "a.png", "image/png", bomb));
    }

    private void assertRefusedQuickly(MockMultipartFile bomb) throws Exception {
        // warm up ImageIO so the timing below measures the guard, not class loading
        storage.storePublic(new MockMultipartFile("w", "w.png", "image/png", encode(split(4, 4), "png")), "warm");
        Files.walk(tmp.resolve("public")).sorted(java.util.Comparator.reverseOrder()).forEach(p -> p.toFile().delete());

        long t0 = System.nanoTime();
        assertThatThrownBy(() -> storage.storePublic(bomb, "avatars"))
                .isInstanceOf(BusinessException.class).hasMessage("upload.error.image_too_large");
        assertThat((System.nanoTime() - t0) / 1_000_000).as("refused in ms").isLessThan(1000);
        assertThat(Files.exists(tmp.resolve("public"))).as("nothing stored").isFalse();
    }

    // ── WebP: EXIF/XMP chunks dropped without a codec ─────────────────────────

    @Test
    void webpExifAndXmpChunksAreDroppedAndTheImageChunkSurvives() throws Exception {
        byte[] image = {1, 2, 3, 4, 5}; // odd length: carries a pad byte
        byte[] webp = webp(
                chunk("VP8X", new byte[]{0x1C, 0, 0, 0, 7, 0, 0, 9, 0, 0}), // alpha + EXIF + XMP flags
                chunk("VP8L", image),
                chunk("EXIF", (GPS + "\0").getBytes(StandardCharsets.US_ASCII)),
                chunk("XMP ", ("<x:xmpmeta>" + GPS + "</x:xmpmeta>").getBytes(StandardCharsets.US_ASCII)));
        assertThat(contains(webp, GPS)).isTrue();

        byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.webp", "image/webp", webp), "avatars"));
        assertThat(contains(stored, GPS)).isFalse();
        assertThat(contains(stored, "EXIF")).isFalse();
        assertThat(contains(stored, "XMP ")).isFalse();
        assertThat(contains(stored, "VP8L")).isTrue();
        assertThat(new String(stored, 0, 4, StandardCharsets.US_ASCII)).isEqualTo("RIFF");
        assertThat(ByteBuffer.wrap(stored).order(ByteOrder.LITTLE_ENDIAN).getInt(4)).isEqualTo(stored.length - 8);
        assertThat(new String(stored, 8, 4, StandardCharsets.US_ASCII)).isEqualTo("WEBP");
        assertThat(stored[20] & 0xFF).as("VP8X flags: EXIF and XMP bits cleared, alpha kept").isEqualTo(0x10);
        assertThat(stored).containsSequence(chunk("VP8L", image));
    }

    @Test
    void aMalformedWebpNeverThrowsAndIsStoredUnchanged() {
        byte[] good = webp(chunk("VP8L", new byte[]{1, 2, 3, 4}), chunk("EXIF", new byte[]{9, 9}));
        byte[] chunkOverrun = good.clone();
        ByteBuffer.wrap(chunkOverrun).order(ByteOrder.LITTLE_ENDIAN).putInt(16, 1000); // first chunk claims 1000 bytes
        byte[] riffTooBig = good.clone();
        ByteBuffer.wrap(riffTooBig).order(ByteOrder.LITTLE_ENDIAN).putInt(4, good.length + 50);
        byte[] riffTooSmall = good.clone();
        ByteBuffer.wrap(riffTooSmall).order(ByteOrder.LITTLE_ENDIAN).putInt(4, 2);
        byte[] shortChunkHeader = java.util.Arrays.copyOf(good, 12 + 5);
        ByteBuffer.wrap(shortChunkHeader).order(ByteOrder.LITTLE_ENDIAN).putInt(4, 9);
        byte[] shortVp8x = webp(chunk("VP8X", new byte[]{0x08, 0}), chunk("VP8L", new byte[]{1, 2}));
        byte[] hugeSize = good.clone();
        ByteBuffer.wrap(hugeSize).order(ByteOrder.LITTLE_ENDIAN).putInt(16, -1); // 4 GiB chunk

        for (byte[] bad : new byte[][]{chunkOverrun, riffTooBig, riffTooSmall, shortChunkHeader, shortVp8x, hugeSize}) {
            byte[] stored = readPublic(storage.storePublic(new MockMultipartFile("i", "a.webp", "image/webp", bad)));
            assertThat(stored).isEqualTo(bad);
        }
    }

    /** A RIFF/WEBP file made of the given chunks. */
    private static byte[] webp(byte[]... chunks) {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        body.writeBytes("WEBP".getBytes(StandardCharsets.US_ASCII));
        for (byte[] c : chunks) body.writeBytes(c);
        ByteBuffer out = ByteBuffer.allocate(8 + body.size()).order(ByteOrder.LITTLE_ENDIAN);
        out.put("RIFF".getBytes(StandardCharsets.US_ASCII)).putInt(body.size()).put(body.toByteArray());
        return out.array();
    }

    /** One RIFF chunk: fourcc, little-endian size, payload, pad byte when the payload length is odd. */
    private static byte[] chunk(String fourcc, byte[] payload) {
        ByteBuffer c = ByteBuffer.allocate(8 + payload.length + (payload.length & 1)).order(ByteOrder.LITTLE_ENDIAN);
        c.put(fourcc.getBytes(StandardCharsets.US_ASCII)).putInt(payload.length).put(payload);
        return c.array();
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

    // ── CR-14: JPEGs the JDK can't decode (CMYK) ────────────────────────────────

    private static byte[] segment(int marker, String payload) {
        byte[] p = payload.getBytes(StandardCharsets.ISO_8859_1);
        return ByteBuffer.allocate(4 + p.length).put((byte) 0xFF).put((byte) marker)
                .putShort((short) (p.length + 2)).put(p).array();
    }

    @Test
    void anUndecodableJpegLosesItsLocationSegmentsButKeepsColourAndImageData() throws IOException {
        BufferedImage img = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "jpeg", out);
        byte[] plain = out.toByteArray();
        // SOI, then EXIF (GPS), XMP, ICC, IPTC, Adobe and a comment, then the rest of the file.
        ByteArrayOutputStream tagged = new ByteArrayOutputStream();
        tagged.write(plain, 0, 2);
        tagged.write(segment(0xE1, "Exif\0\0GPSLatitude=30.0444"));
        tagged.write(segment(0xE1, "http://ns.adobe.com/xap/1.0/\0<exif:GPSLongitude>31.2357"));
        tagged.write(segment(0xE2, "ICC_PROFILE\0colour"));
        tagged.write(segment(0xED, "Photoshop 3.0\0IPTC-City=Cairo"));
        tagged.write(segment(0xEE, "Adobe\0transform"));
        tagged.write(segment(0xFE, "taken at home"));
        tagged.write(plain, 2, plain.length - 2);
        byte[] in = tagged.toByteArray();

        byte[] stripped = FileStorageServiceImpl.stripJpegMetadata(in);

        String s = new String(stripped, StandardCharsets.ISO_8859_1);
        assertThat(s).doesNotContain("GPSLatitude").doesNotContain("GPSLongitude")
                .doesNotContain("IPTC-City").doesNotContain("taken at home");
        assertThat(s).contains("ICC_PROFILE").contains("Adobe");
        // Only the personal segments went: SOI + ICC + Adobe + the original file after SOI, byte for byte.
        int kept = segment(0xE2, "ICC_PROFILE\0colour").length + segment(0xEE, "Adobe\0transform").length;
        assertThat(stripped.length).isEqualTo(2 + kept + plain.length - 2);
        assertThat(java.util.Arrays.copyOfRange(stripped, 2 + kept, stripped.length))
                .isEqualTo(java.util.Arrays.copyOfRange(plain, 2, plain.length));
        // Without the fake colour segments the result still decodes.
        ByteArrayOutputStream gpsOnly = new ByteArrayOutputStream();
        gpsOnly.write(plain, 0, 2);
        gpsOnly.write(segment(0xE1, "Exif\0\0GPSLatitude=30.0444"));
        gpsOnly.write(plain, 2, plain.length - 2);
        BufferedImage back = ImageIO.read(new ByteArrayInputStream(
                FileStorageServiceImpl.stripJpegMetadata(gpsOnly.toByteArray())));
        assertThat(back.getWidth()).isEqualTo(8);
    }

    @Test
    void aMalformedJpegIsNotStripped() {
        assertThat(FileStorageServiceImpl.stripJpegMetadata(new byte[]{(byte) 0xFF, (byte) 0xD8, 0x00, 0x01, 0x02}))
                .isNull();
        assertThat(FileStorageServiceImpl.stripJpegMetadata("not a jpeg".getBytes(StandardCharsets.UTF_8))).isNull();
    }
}
