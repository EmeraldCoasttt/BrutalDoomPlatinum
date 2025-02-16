void main()
{
	// DIFX_BlackArmor
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	float rcol = (src.r + src.g + src.b);
	
	rcol = clamp(rcol, 0.0, 1.0);
	vec4 vision = vec4(src.r, rcol * 0.25, rcol * 0.25, 1.0);

	float outerRadius = 1.0;
	float innerRadius = 0.65;
	vec4 vignetteColor = vec4(0.0, 0.0, 0.0, 1.0);
	
	vec2 relativePosition = gl_FragCoord.xy / texSize - 0.5;
	
    relativePosition.y *= texSize.x / texSize.y;
    float len = length(relativePosition);
	
	float vignetteOpacity = smoothstep(innerRadius, outerRadius, len) * 1.0;
	
	vision.rgb = mix(vision.rgb, vignetteColor.rgb, vignetteOpacity);
	
	vec4 result = vec4(src.r, src.g, src.b, 1.0);
	result.rgb = mix(src.rgb, vision.rgb, clamp(intensity, 0.0, 1.0));
	
    FragColor = vec4(result);
}