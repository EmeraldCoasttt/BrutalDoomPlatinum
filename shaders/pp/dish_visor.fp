void main()
{
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	
	vec4 result = vec4(src.r * 0.75, src.g * 1.5, src.b * 0.75, 1.0);
	
	float exposure = 13;
	float exp = abs(exposure);
	float expcurve = 2.0 * ((150.0 - abs(exposure)) / 100.0);
	exp = exp / expcurve;
	
	vec2 res = TexCoord;
	vec3 color = texture(InputTexture, res).rgb;
	color = mix(vec3(dot(color.rgb, vec3(0.56, 0.3, 0.14))), color.rgb, 0.0);
	color *= max(exp, 1.0);
	
	color = vec3(
		clamp(color.r, 0.0, 1.0),
		clamp(color.g, 0.0, 1.0),
		clamp(color.b, 0.0, 1.0));
	
	vec3 posfilter = normalize(vec3(0.00, 1.0, 0.75)); // primary NVG color (positive exposure)
	vec3 negfilter = normalize(vec3(1.0, 0.0, 0.0)); // secondary NVG color (negative exposure)
	float whiteclip = 1.0;
	
	if (exposure > 0) { color *= clamp(posfilter + (color * whiteclip), 0.0, 1.0); }
	if (exposure < 0) { color *= clamp(negfilter + (color * whiteclip), 0.0, 1.0); }
	
	result = vec4(color.r, color.g, color.b, 1.0);
	
	result = src;
	
    FragColor = vec4(result);
}