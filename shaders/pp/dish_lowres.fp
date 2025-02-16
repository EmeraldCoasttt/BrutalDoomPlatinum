void main() 
{
	vec2 texSize = textureSize(InputTexture, 0);
	vec2 finalResolution = vec2(int(texSize.x) / 6, int(texSize.y) / 6);
	
	vec2 coord;
	coord = vec2((floor(TexCoord.x * finalResolution.x) + 0.25) / finalResolution.x,(floor(TexCoord.y * finalResolution.y) + 0.5) / finalResolution.y);
	
	FragColor = texture(InputTexture, coord);
}