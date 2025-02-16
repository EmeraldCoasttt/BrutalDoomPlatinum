void main()
{
	float outerRadius = 1.0;
	float innerRadius = 0.2;
	float intensity = 1.0;
	
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	float rcol = (src.r + src.g + src.b);
	vec4 vignetteColor = vec4(0.1, 0.1, 0.1, 1.0);
	
	vec2 relativePosition = gl_FragCoord.xy / texSize - .5;
	
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	
	rcol = clamp(rcol, 0.0, 1.0);
	vec4 result = vec4(rcol, rcol, rcol, 1.0);
	
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * intensity;
	result.rgb = mix(result.rgb, vignetteColor.rgb, vignetteOpacity);
	
    FragColor = vec4(result);
}