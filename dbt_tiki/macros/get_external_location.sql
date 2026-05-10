
{% macro get_external_location(model_name) %}
    {% if target.name != 'trino' %}
        {% set location = 's3://lakehouse/marts/' ~ model_name ~ '.parquet' %}
        {{ return(location) }}
    {% else %}
        {{ return(none) }}
    {% endif %}
{% endmacro %}
