vec4 ProcessTexel()
{
    vec4 texel = getTexel(vTexCoord.st);
    texel.b = 1.0;
    return texel;
}


