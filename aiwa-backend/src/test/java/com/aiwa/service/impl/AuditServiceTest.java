package com.aiwa.service.impl;

import com.aiwa.entity.AuditLogEntry;
import com.aiwa.repository.AuditLogRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class AuditServiceTest {

    private final AuditLogRepository repo = mock(AuditLogRepository.class);
    private final AuditService service = new AuditService(repo);

    @Test
    void recordsActorActionTarget() {
        service.record("An Admin", "PROVIDER_APPROVED", "Nadia Studio");

        ArgumentCaptor<AuditLogEntry> captor = ArgumentCaptor.forClass(AuditLogEntry.class);
        verify(repo).save(captor.capture());
        AuditLogEntry saved = captor.getValue();
        assertThat(saved.getActor()).isEqualTo("An Admin");
        assertThat(saved.getAction()).isEqualTo("PROVIDER_APPROVED");
        assertThat(saved.getTarget()).isEqualTo("Nadia Studio");
    }

    @Test
    void loggingFailureNeverPropagates() {
        doThrow(new RuntimeException("db down")).when(repo).save(any());
        // Must not throw — audit is best-effort.
        service.record("admin", "USER_DELETED", "someone");
        verify(repo).save(any());
    }

    @Test
    void nullActorDefaultsToSystem() {
        service.record(null, "COMMISSION_RATE_UPDATED", "12%");
        ArgumentCaptor<AuditLogEntry> captor = ArgumentCaptor.forClass(AuditLogEntry.class);
        verify(repo).save(captor.capture());
        assertThat(captor.getValue().getActor()).isEqualTo("system");
    }
}
