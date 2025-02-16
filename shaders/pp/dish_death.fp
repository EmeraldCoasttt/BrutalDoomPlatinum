void main()
{
	float vouterRadius = 1.0;
	float vinnerRadius = 0.3;
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	
	// VINGETTE
	vec4 vignetteColor = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 relativePosition = gl_FragCoord.xy / texSize - .5;
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	float vignetteOpacity = smoothstep(vinnerRadius, vouterRadius, len) * intensity;
	
	vec4 redResult = vec4(src.r, 0.0, 0.0, 1.0);
	redResult.rgb = mix(redResult.rgb, vignetteColor.rgb, vignetteOpacity);
	
	vec4 result = vec4(src.r, src.b, src.g, 1.0);
	result.rgb = mix(result.rgb, vignetteColor.rgb, vignetteOpacity);
	result.rgb = mix(src.rgb, redResult.rgb, intensity);
	
    FragColor = vec4(result);
}