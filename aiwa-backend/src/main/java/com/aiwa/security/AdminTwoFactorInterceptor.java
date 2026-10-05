package com.aiwa.security;

import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * E-1 / AU-09 / F-03: every admin (SUPER_ADMIN, FINANCE, SUPPORT or none) must turn on
 * two-factor sign-in before using the API as an admin. Until then every call except
 * /auth/** (profile, 2FA setup, which the panel needs to walk them through the setup)
 * answers 403 with code {@value #CODE}. SA-01: this covers every route, not only
 * /admin/**, because publishing terms or changing support settings are admin
 * capabilities that live outside that prefix.
 *
 * <p>On with {@code aiwa.auth.require-admin-2fa=true} (the prod profile).
 */
@Component
@RequiredArgsConstructor
public class AdminTwoFactorInterceptor implements HandlerInterceptor, WebMvcConfigurer {

    public static final String CODE = "auth.error.admin_2fa_required";

    private final UserRepository userRepo;
    private final com.aiwa.i18n.MessageHelper messages;

    @Value("${aiwa.auth.require-admin-2fa:false}")
    private boolean required;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(this).addPathPatterns("/**")
                .excludePathPatterns("/auth/**", "/actuator/**", "/error");
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if (!required) return true;
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserDetails ud)) return true;
        Long id = AiwaUserDetails.idOf(ud);
        var user = id != null ? userRepo.findById(id) : userRepo.findByLogin(ud.getUsername());
        if (user.isEmpty() || user.get().getRole() != UserRole.ADMIN || user.get().isTotpEnabled()) return true;
        var u = user.get();
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(new com.fasterxml.jackson.databind.ObjectMapper().createObjectNode()
                .put("success", false).put("status", 403).put("error", "Forbidden")
                .put("code", CODE).put("message", messages.get(CODE))
                .put("timestamp", java.time.LocalDateTime.now().toString()).toString());
        return false;
    }
}
