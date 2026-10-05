package com.aiwa.api;

import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Contract guard (roadmap P3): the list of HTTP operations and the request/response schema names the API exposes is
 * recorded in {@code src/test/resources/api-contract/operations.txt} and the DTO schemas' property names in
 * {@code schemas.txt}. The mobile app and the admin dashboard are written against these; a change to either list
 * therefore fails this test until it is reviewed and the snapshot is regenerated on purpose:
 * <pre>mvn test -Dtest=ApiContractSnapshotTest -Dapi.contract.update=true</pre>
 * Review the diff of those files together with the Flutter and dashboard changes it implies.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiContractSnapshotTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final Path DIR = Path.of("src/test/resources/api-contract");

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test
    void operationsAndSchemasMatchTheRecordedContract() throws Exception {
        String body = mvc.perform(get("/v3/api-docs")).andExpect(status().isOk()).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        JsonNode docs = json.readTree(body);

        TreeSet<String> operations = new TreeSet<>();
        Iterator<Map.Entry<String, JsonNode>> paths = docs.get("paths").fields();
        while (paths.hasNext()) {
            Map.Entry<String, JsonNode> path = paths.next();
            Iterator<String> methods = path.getValue().fieldNames();
            while (methods.hasNext()) operations.add(methods.next().toUpperCase() + " " + path.getKey());
        }

        TreeSet<String> schemas = new TreeSet<>();
        JsonNode components = docs.path("components").path("schemas");
        Iterator<Map.Entry<String, JsonNode>> it = components.fields();
        while (it.hasNext()) {
            Map.Entry<String, JsonNode> schema = it.next();
            List<String> props = new ArrayList<>();
            schema.getValue().path("properties").fieldNames().forEachRemaining(props::add);
            props.sort(String::compareTo);
            schemas.add(schema.getKey() + ": " + String.join(", ", props));
        }

        check("operations.txt", operations);
        check("schemas.txt", schemas);
    }

    private void check(String file, TreeSet<String> actual) throws Exception {
        Path target = DIR.resolve(file);
        String text = String.join("\n", actual) + "\n";
        if (Boolean.getBoolean("api.contract.update") || !Files.exists(target)) {
            Files.createDirectories(DIR);
            Files.writeString(target, text, StandardCharsets.UTF_8);
        }
        List<String> expected = Files.readAllLines(target, StandardCharsets.UTF_8).stream()
                .filter(l -> !l.isBlank()).toList();
        assertThat(new ArrayList<>(actual))
                .as(file + " differs from the recorded API contract; review the change with the mobile app and the dashboard, "
                        + "then regenerate with -Dapi.contract.update=true")
                .containsExactlyElementsOf(expected);
    }
}
