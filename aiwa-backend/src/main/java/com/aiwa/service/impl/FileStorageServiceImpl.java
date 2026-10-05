package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.exception.TooManyRequestsException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.Arrays;
import java.util.Iterator;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

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
 *
 * Public images are re-encoded on the way in (CR-14): that drops EXIF/GPS and
 * text chunks, applies the EXIF orientation first so phone photos stay upright,
 * and bounds the longest side. Private documents are stored byte for byte.
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

    /** Longest side, in pixels, of a stored public image; larger uploads are scaled down. */
    @Value("${aiwa.storage.public-max-image-side:2048}")
    private int maxImageSide = 2048;

    /** Largest declared width x height accepted for a public image; bigger ones are refused before any decode. */
    @Value("${aiwa.storage.public-max-image-pixels:200000000}")
    private long maxImagePixels = 200_000_000L;

    /**
     * Largest declared width x height accepted for a progressive JPEG. libjpeg keeps every coefficient of a
     * progressive image in native memory while it decodes (the heap limit and the subsampling do not bound that),
     * so a ~1 MB file declaring 14142 x 14142 would pin hundreds of MB and ~40 s of CPU.
     */
    @Value("${aiwa.storage.public-max-progressive-pixels:25000000}")
    private long maxProgressivePixels = 25_000_000L;

    /**
     * Largest declared width or height accepted for a public image. The pixel ceiling alone does not bound the
     * decoder: JDK PNG/JPEG readers allocate scanline buffers for the full source width even when subsampling, so a
     * 20,000,000 x 1 header passes an area check and still exhausts the heap (audit B-01).
     */
    @Value("${aiwa.storage.public-max-image-dimension:16384}")
    private int maxImageDimension = 16384;

    /** Upper bound for the estimated working memory (scanlines plus the subsampled destination) of one decode. */
    @Value("${aiwa.storage.public-max-decode-working-bytes:134217728}")
    private long maxDecodeWorkingBytes = 128L * 1024 * 1024;

    /** Public-image decodes allowed at the same time; the others wait (at most {@link #decodeWaitMillis}) for a slot. */
    private Semaphore decodeSlots = new Semaphore(2, true);

    @Value("${aiwa.storage.public-decode-wait-ms:5000}")
    private long decodeWaitMillis = 5000L;

    @Value("${aiwa.storage.public-decode-concurrency:2}")
    void setPublicDecodeConcurrency(int permits) {
        decodeSlots = new Semaphore(Math.max(1, permits), true);
    }

    /** Encrypts private files when DOCUMENT_ENCRYPTION_KEY is set; a test seam, so not final. */
    private com.aiwa.util.PrivateFileCipher privateCipher = new com.aiwa.util.PrivateFileCipher(System.getenv("DOCUMENT_ENCRYPTION_KEY"));

    /** The contents of a stored private file, decrypted when it was written encrypted. */
    public byte[] readPrivate(Path path) throws IOException {
        return privateCipher.decrypt(Files.readAllBytes(path));
    }

    /** Store a public gallery image; returns its public URL path. */
    public String storePublic(MultipartFile file) {
        return storePublic(file, "gallery");
    }

    /** Store a public image in {@code folder} (e.g. "gallery", "avatars"); returns its public URL path. */
    public String storePublic(MultipartFile file, String folder) {
        String ext = validate(file);
        String filename = store(file, stripMetadata(file, ext), publicPath, folder, ext);
        return PUBLIC_URL_PREFIX + folder + "/" + filename;
    }

    /**
     * Store a private verification document — NOT exposed via public URL.
     * Returns the storage path ("uploads/private/&lt;sub&gt;/&lt;file&gt;").
     */
    public String storePrivate(MultipartFile file, String subfolder) {
        String ext = validate(file);
        String filename = store(file, null, privatePath, subfolder, ext);
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

    /**
     * Re-encode a JPEG/PNG without metadata, upright and at most {@link #maxImageSide} px on the longest side;
     * WebP has no JDK codec, so its EXIF/XMP chunks are cut out of the RIFF container instead.
     * Returns null when the bytes cannot be processed (CMYK JPEGs, malformed files): the caller then stores the
     * upload unchanged, as before, and the location data of those files is NOT removed.
     * An image whose declared size is above {@link #maxImagePixels} is refused (a real photo is never that large,
     * and decoding it would cost seconds of CPU), a progressive JPEG above {@link #maxProgressivePixels}; at most a
     * few images are decoded at once, a request that cannot get a slot in time is answered 429.
     */
    private byte[] stripMetadata(MultipartFile file, String ext) {
        byte[] data = null;
        try {
            data = file.getBytes();
            if ("webp".equals(ext)) {
                return stripWebpMetadata(data);
            }
            if ("jpg".equals(ext) && progressivePixels(data) > maxProgressivePixels) {
                throw new BusinessException("upload.error.image_too_large");
            }
            try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(data))) {
                Iterator<ImageReader> readers = ImageIO.getImageReaders(in);
                if (!readers.hasNext()) {
                    return undecodable(data, ext, "no decoder");
                }
                ImageReader reader = readers.next();
                try {
                    reader.setInput(in, true, true);
                    int width = reader.getWidth(0), height = reader.getHeight(0); // header only, no pixel decode
                    if (width <= 0 || height <= 0 || (long) width * height > maxImagePixels) {
                        throw new BusinessException("upload.error.image_too_large");
                    }
                    // B-01: bound every dimension and the decoder's working memory before reader.read allocates.
                    int subsampling = Math.max(1, Math.max(width, height) / maxImageSide);
                    if (width > maxImageDimension || height > maxImageDimension
                            || estimatedDecodeBytes(width, height, subsampling) > maxDecodeWorkingBytes) {
                        throw new BusinessException("upload.error.image_too_large");
                    }
                    // H-3, second guard: ask the decoder itself, so a header our marker walk reads
                    // differently from libjpeg still can't slip a large progressive frame through.
                    if ("jpg".equals(ext) && (long) width * height > maxProgressivePixels && !isBaselineJpeg(reader)) {
                        throw new BusinessException("upload.error.image_too_large");
                    }
                    ImageReadParam param = reader.getDefaultReadParam();
                    // Decode a subsampled copy of very large images so the decode itself stays bounded.
                    int sub = subsampling;
                    param.setSourceSubsampling(sub, sub, 0, 0);
                    final byte[] bytes = data;
                    return withDecodeSlot(() -> {
                        BufferedImage src = reader.read(0, param);
                        boolean png = "png".equals(ext);
                        return encode(src, png, png ? 1 : exifOrientation(bytes));
                    });
                } finally {
                    reader.dispose();
                }
            }
        } catch (BusinessException e) {
            throw e;
        } catch (IOException | RuntimeException e) {
            return undecodable(data, ext, e.toString());
        }
    }

    /**
     * Rough upper bound of the heap one decode needs: a few full-width scanline buffers (up to 16 bytes per pixel
     * for 16-bit RGBA with filter/previous-row copies) plus the subsampled destination raster (4 bytes per pixel).
     */
    static long estimatedDecodeBytes(int width, int height, int subsampling) {
        long scanlines = 4L * 16L * width;
        long destination = 4L * (((long) width + subsampling - 1) / subsampling)
                * (((long) height + subsampling - 1) / subsampling);
        return scanlines + destination;
    }

    /**
     * CR-14: a JPEG the JDK can't decode (CMYK, unusual sampling) used to be stored with
     * its EXIF GPS position. Its metadata segments are cut out instead; anything else
     * that can't be processed is stored unchanged, as before.
     */
    private byte[] undecodable(byte[] data, String ext, String why) {
        if ("jpg".equals(ext) && data != null) {
            byte[] stripped = stripJpegMetadata(data);
            if (stripped != null) {
                log.info("Public JPEG not re-encoded ({}); metadata segments removed", why);
                return stripped;
            }
        }
        log.warn("Public image stored unchanged: could not re-encode ({}), metadata not stripped", why);
        return null;
    }

    /**
     * Copies a JPEG without the segments that carry personal metadata: APP1 (EXIF with GPS,
     * XMP), APP3–APP13 (IPTC, maker data), APP15 and comments. APP0 (JFIF), APP2 (ICC colour
     * profile) and APP14 (Adobe, needed to show CMYK colours right) stay. Everything from the
     * first scan on is copied as is. Returns null for anything that doesn't parse.
     */
    static byte[] stripJpegMetadata(byte[] jpeg) {
        if (jpeg.length < 4 || (jpeg[0] & 0xFF) != 0xFF || (jpeg[1] & 0xFF) != 0xD8) return null;
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream(jpeg.length);
        out.write(0xFF);
        out.write(0xD8);
        int i = 2;
        while (i + 4 <= jpeg.length) {
            if ((jpeg[i] & 0xFF) != 0xFF) return null;
            int marker = jpeg[i + 1] & 0xFF;
            if (marker == 0xFF) { i++; continue; }
            if (marker == 0xDA) { // start of scan: the rest is image data
                out.write(jpeg, i, jpeg.length - i);
                return out.toByteArray();
            }
            if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) { out.write(jpeg, i, 2); i += 2; continue; }
            int len = ((jpeg[i + 2] & 0xFF) << 8) | (jpeg[i + 3] & 0xFF);
            if (len < 2 || i + 2 + len > jpeg.length) return null;
            boolean personal = marker == 0xFE                                   // COM
                    || marker == 0xE1                                           // APP1: EXIF, XMP
                    || (marker >= 0xE3 && marker <= 0xED) || marker == 0xEF;    // APP3-13, APP15
            if (!personal) out.write(jpeg, i, 2 + len);
            i += 2 + len;
        }
        return null;
    }

    @FunctionalInterface
    interface IoSupplier<T> {
        T get() throws IOException;
    }

    /** Runs {@code work} holding one decode slot; answers 429 when none frees up within the wait. */
    <T> T withDecodeSlot(IoSupplier<T> work) throws IOException {
        boolean got;
        try {
            got = decodeSlots.tryAcquire(decodeWaitMillis, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            got = false;
        }
        if (!got) throw new TooManyRequestsException("error.too_many_requests");
        try {
            return work.get();
        } finally {
            decodeSlots.release();
        }
    }

    /**
     * True only when the JPEG reader's header metadata names a sequential frame (SOF process 0 or 1).
     * Progressive, lossless, or metadata that can't be read all count as "not baseline".
     */
    static boolean isBaselineJpeg(ImageReader reader) {
        try {
            javax.imageio.metadata.IIOMetadata md = reader.getImageMetadata(0);
            org.w3c.dom.Node root = md.getAsTree("javax_imageio_jpeg_image_1.0");
            org.w3c.dom.NodeList sofs = ((org.w3c.dom.Element) root).getElementsByTagName("sof");
            if (sofs.getLength() == 0) return false;
            org.w3c.dom.Node process = sofs.item(0).getAttributes().getNamedItem("process");
            return process != null && ("0".equals(process.getNodeValue()) || "1".equals(process.getNodeValue()));
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Declared width x height of a progressive JPEG (frame types SOF2, SOF6, SOF10, SOF14), read from the marker
     * segments without decoding; 0 for a baseline JPEG or anything that does not parse (ImageIO then decides).
     * H-3: bytes between segments that are not a marker are skipped, as libjpeg skips them ("extraneous bytes
     * before marker") and decodes on. Stopping there let one junk byte hide a huge progressive frame.
     */
    static long progressivePixels(byte[] jpeg) {
        int i = 2; // after SOI
        while (i + 4 <= jpeg.length) {
            if ((jpeg[i] & 0xFF) != 0xFF) { i++; continue; }             // junk before a marker: resync
            int marker = jpeg[i + 1] & 0xFF;
            if (marker == 0xFF) { i++; continue; }                       // fill byte
            if (marker == 0x00) { i += 2; continue; }                    // not a marker: junk
            if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) { i += 2; continue; } // no length
            if (marker == 0xD9 || marker == 0xDA) return 0;              // end, or scan data: no frame header before it
            int len = ((jpeg[i + 2] & 0xFF) << 8) | (jpeg[i + 3] & 0xFF);
            boolean frame = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
            if (frame) {
                if (marker % 4 != 2 || i + 9 > jpeg.length) return 0;    // C2, C6, CA, CE are the progressive ones
                int height = ((jpeg[i + 5] & 0xFF) << 8) | (jpeg[i + 6] & 0xFF);
                int width = ((jpeg[i + 7] & 0xFF) << 8) | (jpeg[i + 8] & 0xFF);
                return (long) width * height;
            }
            i += 2 + len;
        }
        return 0;
    }

    /**
     * Copies a WebP's RIFF container without its {@code EXIF} and {@code XMP } chunks, clears the matching flag
     * bits in {@code VP8X} and fixes the RIFF size. Returns null (store unchanged) for anything malformed.
     */
    static byte[] stripWebpMetadata(byte[] webp) {
        try {
            ByteBuffer in = ByteBuffer.wrap(webp).order(ByteOrder.LITTLE_ENDIAN);
            long riffEnd = 8 + (in.getInt(4) & 0xFFFFFFFFL);
            if (webp.length < 12 || riffEnd < 12 || riffEnd > webp.length) {
                throw new IllegalArgumentException("bad RIFF size");
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream(webp.length);
            out.write(webp, 0, 12); // "RIFF" + size (fixed below) + "WEBP"
            int pos = 12;
            while (pos < riffEnd) {
                if (pos + 8 > riffEnd) throw new IllegalArgumentException("short chunk header");
                long size = in.getInt(pos + 4) & 0xFFFFFFFFL;
                if (size > riffEnd - pos - 8) throw new IllegalArgumentException("chunk overruns the file");
                int next = (int) Math.min(pos + 8 + size + (size & 1), riffEnd); // a last odd chunk may lack its pad byte
                String id = new String(webp, pos, 4, StandardCharsets.ISO_8859_1);
                if (!id.equals("EXIF") && !id.equals("XMP ")) {
                    byte[] chunk = Arrays.copyOfRange(webp, pos, next);
                    if (id.equals("VP8X")) {
                        if (size < 10) throw new IllegalArgumentException("short VP8X");
                        chunk[8] &= ~0x0C; // EXIF (0x08) and XMP (0x04) flags
                    }
                    out.write(chunk, 0, chunk.length);
                }
                pos = next;
            }
            byte[] result = out.toByteArray();
            ByteBuffer.wrap(result).order(ByteOrder.LITTLE_ENDIAN).putInt(4, result.length - 8);
            return result;
        } catch (RuntimeException e) { // short, truncated or inconsistent RIFF: leave the upload as it is
            log.warn("Public WebP stored unchanged: could not strip metadata ({})", e.toString());
            return null;
        }
    }

    private byte[] encode(BufferedImage src, boolean png, int orientation) throws IOException {
        int w = src.getWidth(), h = src.getHeight();
        boolean swap = orientation >= 5;
        int rw = swap ? h : w, rh = swap ? w : h;
        double scale = Math.min(1.0, (double) maxImageSide / Math.max(rw, rh));
        int dw = Math.max(1, (int) Math.round(rw * scale)), dh = Math.max(1, (int) Math.round(rh * scale));

        BufferedImage out = new BufferedImage(dw, dh, png ? BufferedImage.TYPE_INT_ARGB : BufferedImage.TYPE_INT_RGB);
        var g = out.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            g.scale(scale, scale);
            g.transform(orientationTransform(orientation, w, h));
            g.drawImage(src, 0, 0, null);
        } finally {
            g.dispose();
        }

        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        if (png) {
            ImageIO.write(out, "png", bytes);
        } else {
            ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
            ImageWriteParam wp = writer.getDefaultWriteParam();
            wp.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            wp.setCompressionQuality(0.9f);
            try (ImageOutputStream ios = ImageIO.createImageOutputStream(bytes)) {
                writer.setOutput(ios);
                writer.write(null, new IIOImage(out, null, null), wp); // null metadata: JFIF only
            } finally {
                writer.dispose();
            }
        }
        return bytes.toByteArray();
    }

    /** Maps the pixels of a w x h image to its upright display, per EXIF orientation 1-8. */
    private static AffineTransform orientationTransform(int orientation, int w, int h) {
        return switch (orientation) {
            case 2 -> new AffineTransform(-1, 0, 0, 1, w, 0);
            case 3 -> new AffineTransform(-1, 0, 0, -1, w, h);
            case 4 -> new AffineTransform(1, 0, 0, -1, 0, h);
            case 5 -> new AffineTransform(0, 1, 1, 0, 0, 0);
            case 6 -> new AffineTransform(0, 1, -1, 0, h, 0);
            case 7 -> new AffineTransform(0, -1, -1, 0, h, w);
            case 8 -> new AffineTransform(0, -1, 1, 0, 0, w);
            default -> new AffineTransform();
        };
    }

    /** EXIF orientation (1-8) from the JPEG's APP1 segment; 1 when absent or unreadable. */
    static int exifOrientation(byte[] jpeg) {
        try {
            int i = 2; // after SOI
            while (i + 4 <= jpeg.length && (jpeg[i] & 0xFF) == 0xFF) {
                int marker = jpeg[i + 1] & 0xFF;
                if (marker == 0xDA) break; // start of scan: no more headers
                int len = ((jpeg[i + 2] & 0xFF) << 8) | (jpeg[i + 3] & 0xFF);
                if (marker == 0xE1 && len >= 16 && jpeg[i + 4] == 'E' && jpeg[i + 5] == 'x'
                        && jpeg[i + 6] == 'i' && jpeg[i + 7] == 'f') {
                    ByteBuffer tiff = ByteBuffer.wrap(jpeg, i + 10, len - 8).slice();
                    tiff.order(tiff.get(0) == 'I' ? ByteOrder.LITTLE_ENDIAN : ByteOrder.BIG_ENDIAN);
                    int ifd = tiff.getInt(4);
                    int entries = tiff.getShort(ifd) & 0xFFFF;
                    for (int e = 0; e < entries; e++) {
                        int at = ifd + 2 + e * 12;
                        if ((tiff.getShort(at) & 0xFFFF) == 0x0112) {
                            int o = tiff.getShort(at + 8) & 0xFFFF;
                            return o >= 1 && o <= 8 ? o : 1;
                        }
                    }
                    return 1;
                }
                i += 2 + len;
            }
        } catch (RuntimeException e) { // short or malformed EXIF: treat as upright
            log.debug("Unreadable EXIF orientation: {}", e.toString());
        }
        return 1;
    }

    /** Writes {@code processed} when given, else the upload's own bytes. */
    private String store(MultipartFile file, byte[] processed, String basePath, String subfolder, String ext) {
        String filename = UUID.randomUUID() + "." + ext;
        Path dir = Paths.get(basePath, subfolder);
        try {
            Files.createDirectories(dir);
            Path dest = dir.resolve(filename);
            if (basePath.equals(privatePath) && privateCipher.enabled()) {
                // AU-08: ID documents and selfies are encrypted at rest (DOCUMENT_ENCRYPTION_KEY).
                Files.write(dest, privateCipher.encrypt(processed != null ? processed : file.getBytes()));
            } else if (processed != null) {
                Files.write(dest, processed);
            } else {
                try (InputStream in = file.getInputStream()) {
                    Files.copy(in, dest, StandardCopyOption.REPLACE_EXISTING);
                }
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
