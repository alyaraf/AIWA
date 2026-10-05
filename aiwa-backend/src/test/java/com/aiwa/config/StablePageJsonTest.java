package com.aiwa.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.module.SimpleModule;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class StablePageJsonTest {

    @Test
    void pagesAreWrittenWithTheFixedFieldSet() throws Exception {
        ObjectMapper mapper = new ObjectMapper().registerModule(new SimpleModule().addSerializer(new StablePageJson()));
        JsonNode json = mapper.readTree(mapper.writeValueAsString(
                new PageImpl<>(List.of("a", "b"), PageRequest.of(1, 2), 5)));

        assertThat(json.fieldNames()).toIterable().containsExactlyInAnyOrder(
                "content", "totalElements", "totalPages", "number", "size", "numberOfElements", "first", "last", "empty");
        assertThat(json.get("content")).hasSize(2);
        assertThat(json.get("totalElements").asLong()).isEqualTo(5);
        assertThat(json.get("totalPages").asInt()).isEqualTo(3);
        assertThat(json.get("number").asInt()).isEqualTo(1);
        assertThat(json.get("last").asBoolean()).isFalse();
    }
}
