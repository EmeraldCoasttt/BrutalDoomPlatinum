layout(location=0) in vec2 TexCoord;
layout(location=0) out vec4 FragColor;

layout(binding=0) uniform sampler2D InputTexture;

void main()
{
	vec2 position = (TexCoord - vec2(0.5));

	vec2 p = vec2(position.x * Aspect, position.y);
	float r2 = dot(p, p);
	vec3 f = vec3(1.0) + r2 * (k.rgb + kcube.rgb * sqrt(r2));

	vec3 x = f * position.x * Scale + 0.5;
	vec3 y = f * position.y * Scale + 0.5;

	vec3 c;
	c.r = texture(InputTexture, vec2(x.r, y.r)).r;
	c.g = texture(InputTexture, vec2(x.g, y.g)).g;
	c.b = texture(InputTexture, vec2(x.b, y.b)).b;

	FragColor = vec4(c, 1.0);
}