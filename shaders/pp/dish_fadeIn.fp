void main()
{
	vec4 src = texture(InputTexture, TexCoord);
	float i = 1.0 - intensity;
	vec4 result = vec4(src.r * i, src.g * i, src.b * i, 1);
	
    FragColor = result;
}