void main()
{
	float outerRadius = 1.0;
	float innerRadius = 0.1;
	
	vec4 src = texture(InputTexture, TexCoord);
	vec2 texSize = textureSize(InputTexture, 0);
	
	vec4 vignetteColor = vec4(0.6, 0.0, 1.0, 1.0);
	vec4 fillColor = vec4(0.5, 0.2, 1.0, 1.0);
	
	vec4 result = src * vignetteColor;
	
    vec2 relativePosition = gl_FragCoord.xy / texSize - .5;
	
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * clamp(intensity, 0.0, 1.0);
	
	vec4 contrasted = vec4(src.r - 0.5, src.g - 0.5, src.b - 0.5, 1.0) * 2.5;
	result.rgb = mix(src.rgb, vignetteColor.rgb, vignetteOpacity * 0.5);
	result.rgb = mix(result.rgb, fillColor.rgb, 0.25 * intensity);
	result.rgb = mix(result.rgb, contrasted.rgb, 0.5 * intensity);
	
    FragColor = vec4(result.r, result.g, result.b, 1.0);
}