
{% macro get_external_location(model_name) %}
    {% set location = 's3://lakehouse/marts/' ~ model_name ~ '.parquet' %}
    {{ return(location) }}
{% endmacro %}
