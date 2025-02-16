void main()
{
	float outerRadius = 1.0;
	float innerRadius = 0.65;
	float intensity = 0.5;
	float time = NewTime;
	
	intensity = abs(sin(time * 0.075)) * 0.5;
	
	vec4 src = texture(InputTexture, TexCoord);
	vec2 texSize = textureSize(InputTexture, 0);
	
	vec4 vignetteColor = vec4(0.8, 0.0, 0.0, 1.0);
	
	vec4 result = src * vignetteColor;
	
    vec2 relativePosition = gl_FragCoord.xy / texSize - 0.5;
	
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * intensity;
	
	result.rgb = mix(src.rgb, vignetteColor.rgb, vignetteOpacity);
	
    FragColor = vec4(result.r, result.g, result.b, 1.0);
}