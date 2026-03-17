shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 root_tint : source_color = vec4(0.72, 0.63, 0.5, 1.0);
uniform vec4 tip_tint : source_color = vec4(0.96, 0.92, 0.8, 1.0);
uniform float alpha_clip = 0.45;
uniform float roughness = 0.9;
uniform float metallic = 0.0;
uniform float sss_strength = 0.2;
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.2;
uniform float wind_scale = 0.6;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float max_distance = 28.0;
uniform float fade_distance = 8.0;
uniform float root_darkness = 0.18;
uniform float top_light = 1.08;
uniform float bottom_light = 0.8;
uniform float wind_mask_power = 1.2;

varying vec3 world_pos;
varying float height_mask;
varying vec4 instance_custom;

void vertex() {
    height_mask = pow(clamp(1.0 - UV.y, 0.0, 1.0), wind_mask_power);
    instance_custom = INSTANCE_CUSTOM;
    vec2 dir = normalize(wind_dir);
    float phase = instance_custom.a * 6.283185;
    vec3 base_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float wave = sin(TIME * wind_speed + (base_world_pos.x + base_world_pos.z) * wind_scale + phase);
    VERTEX.x += dir.x * wave * wind_strength * height_mask;
    VERTEX.z += dir.y * wave * wind_strength * height_mask;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    float alpha = tex.a;
    if (fade_distance > 0.0) {
        float dist = distance(CAMERA_POSITION_WORLD, world_pos);
        float fade = smoothstep(max_distance, max_distance - fade_distance, dist);
        alpha *= fade;
    }
    vec3 vertical_tint = mix(root_tint.rgb * (1.0 - root_darkness), tip_tint.rgb, height_mask);
    vec3 tint = base_tint.rgb * vertical_tint * instance_custom.rgb;
    float light_mask = mix(bottom_light, top_light, height_mask);
    ALBEDO = tex.rgb * tint * light_mask;
    ALPHA = alpha;
    ALPHA_SCISSOR_THRESHOLD = alpha_clip;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    SSS_STRENGTH = sss_strength;
}
