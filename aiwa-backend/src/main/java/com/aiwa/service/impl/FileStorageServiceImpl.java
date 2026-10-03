package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
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
import java.nio.file.*;
import java.util.Iterator;
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
     * Re-encode a JPEG/PNG without metadata, upright and at most {@link #maxImageSide} px on the longest side.
     * Returns null when ImageIO cannot decode the bytes (WebP has no JDK reader; CMYK JPEGs): the caller then
     * stores the upload unchanged, as before, and the location data of those files is NOT removed.
     */
    private byte[] stripMetadata(MultipartFile file, String ext) {
        if ("webp".equals(ext)) { // ponytail: no WebP codec in the JDK; add a library if WebP uploads matter
            log.warn("Public WebP stored unchanged: metadata not stripped");
            return null;
        }
        try {
            byte[] data = file.getBytes();
            try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(data))) {
                Iterator<ImageReader> readers = ImageIO.getImageReaders(in);
                if (!readers.hasNext()) {
                    log.warn("Public image stored unchanged: no decoder, metadata not stripped");
                    return null;
                }
                ImageReader reader = readers.next();
                try {
                    reader.setInput(in, true, true);
                    ImageReadParam param = reader.getDefaultReadParam();
                    // Decode a subsampled copy of very large images so the decode itself stays bounded.
                    int sub = Math.max(1, Math.max(reader.getWidth(0), reader.getHeight(0)) / maxImageSide);
                    param.setSourceSubsampling(sub, sub, 0, 0);
                    BufferedImage src = reader.read(0, param);
                    boolean png = "png".equals(ext);
                    return encode(src, png, png ? 1 : exifOrientation(data));
                } finally {
                    reader.dispose();
                }
            }
        } catch (IOException | RuntimeException e) {
            log.warn("Public image stored unchanged: could not re-encode ({})", e.toString());
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
            if (processed != null) {
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
