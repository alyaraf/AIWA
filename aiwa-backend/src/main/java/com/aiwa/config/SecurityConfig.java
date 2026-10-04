package com.aiwa.config;

import com.aiwa.security.JwtAuthFilter;
import com.aiwa.security.RedisRateLimitFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final RedisRateLimitFilter redisRateLimitFilter;
    private final UserDetailsService userDetailsService;
    private final com.aiwa.i18n.MessageHelper messages;

    /** The {@code code} of a 403 caused by the caller's role, not by a business rule. */
    public static final String ROLE_FORBIDDEN_CODE = "auth.error.forbidden_role";

    private void writeError(jakarta.servlet.http.HttpServletResponse response, HttpStatus status,
                            String error, String key) throws java.io.IOException {
        response.setStatus(status.value());
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        com.fasterxml.jackson.databind.node.ObjectNode body =
                com.fasterxml.jackson.databind.json.JsonMapper.builder().build().createObjectNode()
                        .put("success", false)
                        .put("status", status.value())
                        .put("error", error)
                        .put("code", key)
                        .put("message", messages.get(key))
                        .put("timestamp", java.time.LocalDateTime.now().toString());
        response.getWriter().write(body.toString());
    }

    @Value("${aiwa.cors.allowed-origins}")
    private List<String> allowedOrigins;

    /**
     * Truly public endpoints. NOTE: list the specific auth routes, not "/auth/**" —
     * a broad wildcard here would shadow the "/auth/me/**" rule below (first match
     * wins) and leave the authenticated profile endpoints unprotected.
     */
    private static final String[] PUBLIC_URLS = {
            "/auth/register",
            "/auth/login",
            "/auth/refresh",
            "/auth/logout",
            "/auth/send-otp",
            "/auth/verify-otp",
            "/auth/reset-password",
            "/auth/2fa/verify",
            "/auth/2fa/server-time",
            "/dev/2fa/**",   // dev-only reset endpoint below; the whole controller is @Profile("local")
            "/actuator/health/**",
            "/actuator/prometheus", // MetricsTokenFilter requires the scrape token
            "/v3/api-docs/**",
            "/swagger-ui/**",
            "/swagger-ui.html"
    };

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // The second (async) dispatch of a streamed response, e.g. the ledger CSV
                        // export (DR-028), belongs to a request that was already authorized.
                        .dispatcherTypeMatchers(jakarta.servlet.DispatcherType.ASYNC).permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers(PUBLIC_URLS).permitAll()
                        .requestMatchers(HttpMethod.GET, "/providers/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/services/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/provider/gallery/**").permitAll()
                        // Uploaded gallery photos and avatars: image loaders send no token.
                        // (Private ID documents are never under this prefix.)
                        .requestMatchers(HttpMethod.GET, "/files/public/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/bookings/slots").permitAll()
                        .requestMatchers(HttpMethod.GET, "/terms/latest").permitAll()
                        .requestMatchers(HttpMethod.GET, "/support/contact").permitAll()
                        .requestMatchers("/auth/me", "/auth/me/**").authenticated()
                        .requestMatchers("/users/me/**").authenticated()
                        .requestMatchers("/providers/*/manage/**").hasRole("PROVIDER")
                        .requestMatchers("/provider/**").hasAnyRole("PROVIDER", "ADMIN")
                        .requestMatchers("/bookings/**").hasAnyRole("CUSTOMER", "PROVIDER", "ADMIN")
                        .anyRequest().authenticated()
                )
                .exceptionHandling(ex -> ex
                        // No / invalid / expired credentials -> 401 (client should re-authenticate).
                        // Authenticated but lacking the required permission -> 403 (handled by
                        // GlobalExceptionHandler; the client shows a "no permission" message, no logout).
                        // Both write the same {success,status,error,code,message,timestamp}
                        // shape as GlobalExceptionHandler (M-9).
                        .authenticationEntryPoint((request, response, authException) ->
                                writeError(response, HttpStatus.UNAUTHORIZED, "Unauthorized", "auth.error.authentication_required"))
                        // A URL rule refused the caller's role. The apps show their
                        // "not for your account" screen only for this code.
                        .accessDeniedHandler((request, response, denied) ->
                                writeError(response, HttpStatus.FORBIDDEN, "Forbidden", ROLE_FORBIDDEN_CODE)))
                .authenticationProvider(authenticationProvider())
                .addFilterBefore(redisRateLimitFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(allowedOrigins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
