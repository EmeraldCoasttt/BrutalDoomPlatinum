void main()
{
	float outerRadius = 1.0;
	float innerRadius = 0.4;
	//float intensity = 0.15;
	
	vec4 src = texture(InputTexture, TexCoord);
	vec2 texSize = textureSize(InputTexture, 0);
	
	vec4 vignetteColor = vec4(0.2, 0.5, 0.15, 1.0);
	
	vec4 result = src * vignetteColor;
	
    vec2 relativePosition = gl_FragCoord.xy / texSize - .5;
	
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * intensity;
	
	result.rgb = mix(src.rgb, vignetteColor.rgb, vignetteOpacity);
	
    FragColor = vec4(result.r, result.g, result.b, 1.0);
}