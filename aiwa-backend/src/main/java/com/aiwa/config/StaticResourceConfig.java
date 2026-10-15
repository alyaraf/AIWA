package com.aiwa.config;

import com.aiwa.repository.GalleryImageRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.util.UrlPathHelper;

/**
 * SRS BR-2 / BR-3:
 *  - Public gallery images are served at /files/public/**
 *  - Private verification documents (national ID, selfie) are NOT exposed here.
 *    They are accessed only through admin-controlled, authenticated endpoints.
 */
@Configuration
@RequiredArgsConstructor
public class StaticResourceConfig implements WebMvcConfigurer {

    private final GalleryImageRepository galleryRepo;

    @Value("${aiwa.storage.public-path:uploads/public}")
    private String publicPath;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Public gallery images — accessible to anyone
        registry.addResourceHandler("/files/public/**")
                .addResourceLocations("file:" + publicPath + "/");

        // NOTE: /files/private/** is intentionally NOT mapped here.
        // Private documents are served only via VerificationController (admin-auth required).
    }

    /**
     * A gallery photo moderation hid answers 404 at its file URL too, not only in the gallery list: the URL
     * stays in caches and shares. The file itself stays where it is, so unhiding, backups and the uploads
     * reconciliation are unchanged. One small indexed lookup per gallery file (V37: hidden rows only).
     */
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override
            public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
                String path = UrlPathHelper.defaultInstance.getPathWithinApplication(request);
                String name = path.substring(path.lastIndexOf('/') + 1);
                if (!name.isEmpty() && galleryRepo.existsByHiddenTrueAndUrlEndingWith("/gallery/" + name)) {
                    response.sendError(HttpServletResponse.SC_NOT_FOUND);
                    return false;
                }
                return true;
            }
        }).addPathPatterns("/files/public/gallery/**");
    }
}
