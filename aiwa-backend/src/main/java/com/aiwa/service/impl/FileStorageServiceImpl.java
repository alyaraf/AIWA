package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.*;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
public class FileStorageServiceImpl {

    private static final Set<String> ALLOWED_IMAGE_TYPES =
            Set.of("image/jpeg", "image/png", "image/webp");
    private static final long MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

    @Value("${aiwa.storage.public-path:uploads/public}")
    private String publicPath;

    @Value("${aiwa.storage.private-path:uploads/private}")
    private String privatePath;

    /**
     * Store a public gallery image — accessible via /files/public/**
     */
    public String storePublic(MultipartFile file) {
        validate(file);
        return store(file, publicPath, "gallery");
    }

    /**
     * Store a private verification document — NOT exposed via public URL.
     * Admin only access through a signed or admin endpoint.
     */
    public String storePrivate(MultipartFile file, String subfolder) {
        validate(file);
        return store(file, privatePath, subfolder);
    }

    public void deletePublic(String filePath) {
        deleteFile(filePath);
    }

    public void deletePrivate(String filePath) {
        deleteFile(filePath);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("upload.error.empty");
        }
        if (!ALLOWED_IMAGE_TYPES.contains(file.getContentType())) {
            throw new BusinessException("upload.error.invalid_type");
        }
        if (file.getSize() > MAX_FILE_SIZE_BYTES) {
            throw new BusinessException("upload.error.too_large");
        }
    }

    private String store(MultipartFile file, String basePath, String subfolder) {
        String ext = StringUtils.getFilenameExtension(file.getOriginalFilename());
        String filename = UUID.randomUUID() + (ext != null ? "." + ext : "");
        Path dir = Paths.get(basePath, subfolder);
        try {
            Files.createDirectories(dir);
            Path dest = dir.resolve(filename);
            Files.copy(file.getInputStream(), dest, StandardCopyOption.REPLACE_EXISTING);
            return dest.toString();
        } catch (IOException e) {
            log.error("Failed to store file", e);
            throw new BusinessException("upload.error.storage_failed");
        }
    }

    private void deleteFile(String filePath) {
        if (filePath == null) return;
        try {
            Files.deleteIfExists(Paths.get(filePath));
        } catch (IOException e) {
            log.warn("Could not delete file: {}", filePath);
        }
    }
}
