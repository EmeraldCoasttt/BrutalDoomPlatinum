
void main()
{
	ivec2 dims			= textureSize( InputTexture, 0 );
	vec2 pxsize			= dnres * dims ;
	vec2 pos			= ivec2( TexCoord * upres ) * pxsize ;
	
	vec2 frac			= ( TexCoord * dims - pos ) / pxsize ;
	frac				= mix( ivec2( frac ), frac, smoothing );
	vec3 upr_colour 	= mix( texelFetch( InputTexture, ivec2( pos ), 0 ).rgb, texelFetch( InputTexture, ivec2( pos + vec2( pxsize.x, 0 )), 0 ).rgb, frac.x );
	vec3 lwr_colour 	= mix( texelFetch( InputTexture, ivec2( pos + vec2( 0, pxsize.y )), 0 ).rgb, texelFetch( InputTexture, ivec2( pos + vec2( pxsize )), 0 ).rgb, frac.x );
	vec3 colour			= mix( upr_colour, lwr_colour, frac.y );
	
	FragColor			= vec4( colour, 1. );
}
