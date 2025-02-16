void main()
{
	float outerRadius = 0.8;
	float innerRadius = 0.05;
	float intensity = 1.0;
	
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	vec4 vignetteColor = vec4(0.0, 0.0, 0.0, 1.0);
	
	vec2 relativePosition = gl_FragCoord.xy / texSize - .5;
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * intensity;
	
	vec4 result = vec4(src.r * 0.5, src.g * 0.25, src.b * 1.25, 1.0);
	result.rgb = mix(result.rgb, vignetteColor.rgb, vignetteOpacity);
	
    FragColor = vec4(result);
	
}