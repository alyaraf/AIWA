package com.aiwa.exception;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.i18n.MessageHelper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The exception handler is where two of the reported gaps get fixed:
 *  - BusinessException messages that use an i18n key now translate to Arabic
 *    when the request's locale is Arabic (and pass through unchanged for the
 *    many call sites that still throw a plain English sentence).
 *  - An oversized upload used to fall into the generic 500 handler with no
 *    useful message; it now gets a dedicated 413 with a clear message.
 */
class GlobalExceptionHandlerTest {

    private final ResourceBundleMessageSource messageSource = new ResourceBundleMessageSource();
    private final GlobalExceptionHandler handler;

    GlobalExceptionHandlerTest() {
        messageSource.setBasename("i18n/messages");
        messageSource.setDefaultEncoding("UTF-8");
        messageSource.setUseCodeAsDefaultMessage(true);
        handler = new GlobalExceptionHandler(new MessageHelper(messageSource));
    }

    @AfterEach
    void resetLocale() {
        LocaleContextHolder.resetLocaleContext();
    }

    @Test
    void translatesAKnownKeyToArabicWhenRequestLocaleIsArabic() {
        LocaleContextHolder.setLocale(Locale.forLanguageTag("ar"));

        var response = handler.handleBusiness(new BusinessException("booking.error.conflict"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        // Arabic bundle text for booking.error.conflict — not the raw key, not English.
        assertThat(response.getBody().getMessage()).contains("محجوز");
    }

    @Test
    void sameKeyStaysEnglishWhenRequestLocaleIsEnglish() {
        LocaleContextHolder.setLocale(Locale.ENGLISH);

        var response = handler.handleBusiness(new BusinessException("booking.error.conflict"));

        assertThat(response.getBody().getMessage()).isEqualTo("This time slot is already booked. Please choose another time");
    }

    @Test
    void anUnmigratedRawSentencePassesThroughUnchanged() {
        LocaleContextHolder.setLocale(Locale.forLanguageTag("ar"));

        // Most BusinessException call sites still throw a plain English sentence
        // rather than a bundle key — useCodeAsDefaultMessage means an unknown
        // "key" just returns itself, so nothing regresses for those.
        var response = handler.handleBusiness(new BusinessException("Something very specific went wrong"));

        assertThat(response.getBody().getMessage()).isEqualTo("Something very specific went wrong");
    }

    @Test
    void aStaleWriteMapsTo409AskingToRefresh() {
        LocaleContextHolder.setLocale(Locale.ENGLISH);
        var response = handler.handleStaleWrite(
                new org.springframework.orm.ObjectOptimisticLockingFailureException(com.aiwa.entity.Booking.class, 55L));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody().getMessage()).contains("Refresh and try again");
    }

    @Test
    void invalidTokenExceptionMapsTo401() {
        var response = handler.handleInvalidToken(new InvalidTokenException("auth.error.token_invalid"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void oversizedUploadMapsTo413WithAClearMessage() {
        var response = handler.handleUploadTooLarge(new MaxUploadSizeExceededException(10L * 1024 * 1024));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.PAYLOAD_TOO_LARGE);
        ApiResponse.Error body = response.getBody();
        assertThat(body.getMessage()).containsIgnoringCase("10 MB");
    }
}
