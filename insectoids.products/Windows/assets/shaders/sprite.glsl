
//@renderpasses 0,1,2

varying vec2 v_TexCoord0;
varying vec4 v_Color;

//@vertex

attribute vec4 a_Position;
attribute vec2 a_TexCoord0;
attribute vec4 a_Color;

uniform mat4 r_ModelViewProjectionMatrix;

uniform vec4 m_ImageColor;

void main(){

	v_TexCoord0=a_TexCoord0;

	v_Color=m_ImageColor * a_Color;
	
	gl_Position=r_ModelViewProjectionMatrix * a_Position;
}

//@fragment

uniform sampler2D m_ImageTexture0;

void main(){

#if MX2_RENDERPASS==0

	gl_FragColor=texture2D( m_ImageTexture0,v_TexCoord0 ) * v_Color;
	
#else

	float alpha=texture2D( m_ImageTexture0,v_TexCoord0 ).a * v_Color.a;

	gl_FragColor=vec4( 0.0,0.0,0.0,alpha );

#endif

}
