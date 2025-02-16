void main()
{
	vec2 texSize = textureSize(InputTexture, 0);

	vec2 uv = TexCoord;
    uv *=  1.0 - uv.yx;
	
	vec4 src = texture(InputTexture, TexCoord);
	float rcol = (src.r + src.g + src.b);
	
	rcol = clamp(rcol, 0.0, 1.0);
	vec4 result = vec4(rcol, rcol, rcol, 1.0);
	result = vec4(1.0 - result.r, 1.0 - result.g, 1.0 - result.b, 1.0);
    FragColor = vec4(result);
}