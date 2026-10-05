package com.aiwa.config;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.SerializerProvider;
import org.springframework.boot.jackson.JsonComponent;
import org.springframework.data.domain.Page;

import java.io.IOException;

/**
 * F-13: every paged API answers with this fixed set of fields, owned by this project. Serializing
 * Spring's {@code PageImpl} directly is not a supported contract (Spring Data warns about it and may
 * change the shape between releases), and the apps depend on these names.
 */
@JsonComponent
public class StablePageJson extends JsonSerializer<Page<?>> {

    @Override
    @SuppressWarnings({"unchecked", "rawtypes"})
    public Class<Page<?>> handledType() {
        return (Class) Page.class;
    }

    @Override
    public void serialize(Page<?> page, JsonGenerator out, SerializerProvider provider) throws IOException {
        out.writeStartObject();
        out.writeFieldName("content");
        provider.defaultSerializeValue(page.getContent(), out);
        out.writeNumberField("totalElements", page.getTotalElements());
        out.writeNumberField("totalPages", page.getTotalPages());
        out.writeNumberField("number", page.getNumber());
        out.writeNumberField("size", page.getSize());
        out.writeNumberField("numberOfElements", page.getNumberOfElements());
        out.writeBooleanField("first", page.isFirst());
        out.writeBooleanField("last", page.isLast());
        out.writeBooleanField("empty", page.isEmpty());
        out.writeEndObject();
    }
}
