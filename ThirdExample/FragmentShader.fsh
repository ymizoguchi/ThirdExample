precision mediump float;
varying lowp vec2 texcoordVarying;
uniform sampler2D textureImage;

void main()
{
    gl_FragColor = texture2D(textureImage, texcoordVarying);
}