package com.aiwa.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * SRS BR-2 / BR-3:
 *  - Public gallery images are served at /files/public/**
 *  - Private verification documents (national ID, selfie) are NOT exposed here.
 *    They are accessed only through admin-controlled, authenticated endpoints.
 */
@Configuration
public class StaticResourceConfig implements WebMvcConfigurer {

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
}
