void main()
{
	float OuterVig = 1.0; // Position for the Outer vignette
	float InnerVig = 0.01; // Position for the inner Vignette Ring
	
	// vec2 uv = TexCoord / textureSize(InputTexture, 0);
	vec2 uv = TexCoord;
	vec4 color = texture(InputTexture, TexCoord);
	vec2 center = vec2(0.25, 0.5); // Center of Screen, offset to the left
	float dist  = distance(center, uv ) * 1.414213; // Distance  between center and the current Uv. Multiplyed by 1.414213 to fit in the range of 0.0 to 1.0 
	float vig = clamp((OuterVig-dist) / (OuterVig-InnerVig),0.0,1.0); // Generate the Vignette with Clamp which go from outer Viggnet ring to inner vignette ring with smooth steps
	
	color *= vig;
	color.r += (1.0 * vig) * 0.0;
	color.g += (1.0 * vig) * 0.0;
	color.b += (1.0 * vig) * 0.0;
	
	FragColor = color;
}