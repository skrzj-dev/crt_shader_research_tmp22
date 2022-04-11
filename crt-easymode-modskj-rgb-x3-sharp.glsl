#version 120

/*
	CRT Shader by EasyMode
	License: GPL

	A flat CRT shader ideally for 1080p or higher displays.

	Recommended Settings:

	Video
	- Aspect Ratio:  4:3
	- Integer Scale: Off

	Shader
	- Filter: Nearest
	- Scale:  Don't Care

	Example RGB Mask Parameter Settings:

	Aperture Grille (Default)
	- Dot Width:  1
	- Dot Height: 1
	- Stagger:    0

	Lottes' Shadow Mask
	- Dot Width:  2
	- Dot Height: 1
	- Stagger:    3
*/

/*
 *
 * POC based on EasyMode CRT shader from Dosbox-X
 * Emulation of CRT monitor display; using translucent "horizontal noise" in order to get pseudo- scanlines.
 *
 */

// Parameter lines go here:
#pragma parameter SHARPNESS_H "Sharpness Horizontal" 1.5 0.0 1.0 0.05
#pragma parameter SHARPNESS_V "Sharpness Vertical" 1.0 0.0 1.0 0.05
#pragma parameter MASK_STRENGTH "Mask Strength" 0.1 0.0 1.0 0.01
#pragma parameter MASK_DOT_WIDTH "Mask Dot Width" 1.0 1.0 100.0 1.0
#pragma parameter MASK_DOT_HEIGHT "Mask Dot Height" 1.0 1.0 100.0 1.0
#pragma parameter MASK_STAGGER "Mask Stagger" 0.0 0.0 100.0 1.0
#pragma parameter MASK_SIZE "Mask Size" 0.0 0.0 100.0 1.0
#pragma parameter GAMMA_INPUT "Gamma Input" 2.0 0.1 5.0 0.1
#pragma parameter GAMMA_OUTPUT "Gamma Output" 1.8 0.1 5.0 0.1
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.0 0.01
#pragma parameter DILATION "Dilation" 1.0 0.0 1.0 1.0

#define XYZ_LINEAR_INTERPOLATION(ARG0, ARG1, ARG2) mix(ARG0, ARG1, ARG2)
#define XYZ_POW(ARG0, ARG1) pow(ARG0, ARG1)
#define XYZ_FLOOR(ARG0) floor(ARG0)
#define XYZ_FRACT(ARG0) fract(ARG0)
#define XYZ_MOD(ARG0, ARG1) mod(ARG0, ARG1)
#define X_INT(ARG0) int(ARG0)
#define XYZ_CLAMP(ARG0, ARG1, ARG2) clamp(ARG0, ARG1, ARG2)
#define XYZ_SQRT(ARG0) sqrt(ARG0)
#define XYZ_STEP(ARG0, ARG1) step(ARG0, ARG1)
#define XYZ_MIN(ARG0, ARG1) min(ARG0, ARG1)
#define XYZ_MAX(ARG0, ARG1) max(ARG0, ARG1)
#define XYZ_ABS(ARG0) abs(ARG0)
#define XYZ_MATRIX4_T mat4
#define XYZ_VECTOR2_T vec2
#define XYZ_VECTOR3_T vec3
#define XYZ_VECTOR4_T vec4

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE XYZ_VECTOR4_T a_position;
COMPAT_ATTRIBUTE XYZ_VECTOR4_T COLOR;
COMPAT_ATTRIBUTE XYZ_VECTOR4_T TexCoord;
COMPAT_VARYING XYZ_VECTOR4_T COL0;
COMPAT_VARYING XYZ_VECTOR2_T XYZ_RES_v_texCoord;

uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyOutputSize;
uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyTextureSize;
uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyInputSize;

void main()
{
	gl_Position = a_position;
	XYZ_RES_v_texCoord = XYZ_VECTOR2_T(a_position.x + 1.0, 1.0 - a_position.y) / 2.0 * rubyInputSize / rubyTextureSize;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out XYZ_VECTOR4_T XYZ_RES_FragColor;
#else
#define COMPAT_VARYING varying
#define XYZ_RES_FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
precision mediump int;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyOutputSize;
uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyTextureSize;
uniform COMPAT_PRECISION XYZ_VECTOR2_T rubyInputSize;
uniform sampler2D XYZ_RES_rubyTexture;
COMPAT_VARYING XYZ_VECTOR2_T XYZ_RES_v_texCoord;

#define FIX(c) XYZ_MAX(XYZ_ABS(c), 1e-5)
#define PI 3.141592653589

#define TEX2D(c) dilate(COMPAT_TEXTURE(XYZ_RES_rubyTexture, c))

// compatibility #defines
#define XYZ_RES_Source XYZ_RES_rubyTexture
#define XYZ_RES_vTexCoord XYZ_RES_v_texCoord.xy


#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float SHARPNESS_H;
uniform COMPAT_PRECISION float SHARPNESS_V;
uniform COMPAT_PRECISION float MASK_STRENGTH;
uniform COMPAT_PRECISION float MASK_DOT_WIDTH;
uniform COMPAT_PRECISION float MASK_DOT_HEIGHT;
uniform COMPAT_PRECISION float MASK_STAGGER;
uniform COMPAT_PRECISION float MASK_SIZE;
uniform COMPAT_PRECISION float GAMMA_INPUT;
uniform COMPAT_PRECISION float GAMMA_OUTPUT;
uniform COMPAT_PRECISION float BRIGHT_BOOST;
uniform COMPAT_PRECISION float DILATION;
#else

/* Variant- specific parameters: */

#define SHARPNESS_H 0.6
#define SHARPNESS_V 0.9
#define MASK_STRENGTH 0.16
// dot size must be 1.0
#define MASK_DOT_WIDTH 1.0
// dot size must be 1.0
#define MASK_DOT_HEIGHT 1.0
// stagger any other than 0.0 or 3.0 for dot width 1.0, dot height 1.0 looks bad: it produces actual stagger, but it looks bad on LCD: "flickering" and flickering anomalies when scrolling screen in vertical direction
// stagger should be kept as 0.0, it's irrelevant for the horizontal noise
#define MASK_STAGGER 0.0
#define MASK_SIZE 1.0
#define DILATION 1.0

#define TARGET_GAMMA_INPUT 1.0
#define TARGET_GAMMA_OUTPUT 1.1
#define TARGET_BRIGHT_BOOST 1.05

/* Variant- specific parameters: done */

#define DEBUG_HALFVIEW_GAMMA_INPUT 1.0
#define DEBUG_HALFVIEW_GAMMA_OUTPUT 1.0
#define DEBUG_HALFVIEW_BRIGHT_BOOST 1.0

#endif

#define CFG_DEBUG_HALFVIEW 0

// Set to 0 to use linear filter and gain speed
#define CFG_ENABLE_LANCZOS 1

XYZ_VECTOR4_T dilate(XYZ_VECTOR4_T col)
{
	XYZ_VECTOR4_T x = XYZ_LINEAR_INTERPOLATION(XYZ_VECTOR4_T(1.0), col, DILATION);

	return col * x;
}

float curve_distance(float x, float sharp)
{

/*
	apply half-circle s-curve to distance for sharper (more pixelated) interpolation
	single line formula for Graph Toy:
	0.5 - XYZ_SQRT(0.25 - (x - XYZ_STEP(0.5, x)) * (x - XYZ_STEP(0.5, x))) * sign(0.5 - x)
*/

	float x_step = XYZ_STEP(0.5, x);
	float curve = 0.5 - XYZ_SQRT(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);

	return XYZ_LINEAR_INTERPOLATION(x, curve, sharp);
}

XYZ_MATRIX4_T get_color_matrix(XYZ_VECTOR2_T co, XYZ_VECTOR2_T dx)
{
	return XYZ_MATRIX4_T(TEX2D(co - dx), TEX2D(co), TEX2D(co + dx), TEX2D(co + 2.0 * dx));
}

XYZ_VECTOR3_T filter_lanczos(XYZ_VECTOR4_T coeffs, XYZ_MATRIX4_T color_matrix)
{
	XYZ_VECTOR4_T col        = color_matrix * coeffs;
	XYZ_VECTOR4_T sample_min = XYZ_MIN(color_matrix[1], color_matrix[2]);
	XYZ_VECTOR4_T sample_max = XYZ_MAX(color_matrix[1], color_matrix[2]);

	col = XYZ_CLAMP(col, sample_min, sample_max);

	return col.rgb;
}

void main()
{
#	define SourceSize XYZ_VECTOR4_T(rubyTextureSize, 1.0 / rubyTextureSize) //either rubyTextureSize or rubyInputSize
#	define outsize XYZ_VECTOR4_T(rubyOutputSize, 1.0 / rubyOutputSize)

	XYZ_VECTOR2_T dx     = XYZ_VECTOR2_T(SourceSize.z, 0.0);
	XYZ_VECTOR2_T dy     = XYZ_VECTOR2_T(0.0, SourceSize.w);
	XYZ_VECTOR2_T pix_co = XYZ_RES_vTexCoord * SourceSize.xy - XYZ_VECTOR2_T(0.5, 0.5);
	XYZ_VECTOR2_T tex_co = ( XYZ_FLOOR(pix_co) + XYZ_VECTOR2_T(0.5, 0.5) ) * SourceSize.zw;
	XYZ_VECTOR2_T dist   = XYZ_FRACT(pix_co);
	float curve_x;
	XYZ_VECTOR3_T col, col2;

#	if CFG_ENABLE_LANCZOS
	curve_x = curve_distance(dist.y, SHARPNESS_V * SHARPNESS_V);

		XYZ_VECTOR4_T coeffs = PI * XYZ_VECTOR4_T(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);

	coeffs = FIX(coeffs);
	coeffs = 2.0 * sin(coeffs) * sin(coeffs * 0.5) / (coeffs * coeffs);
	coeffs /= dot(coeffs, XYZ_VECTOR4_T(1.0));

	col  = filter_lanczos(coeffs, get_color_matrix(tex_co, dy));
	col2 = filter_lanczos(coeffs, get_color_matrix(tex_co + dx, dy));
#	else
	curve_x = curve_distance(dist.y, SHARPNESS_V); // mod

		col  = XYZ_LINEAR_INTERPOLATION(TEX2D(tex_co).rgb,      TEX2D(tex_co + dy).rgb,      curve_x); //mod
		col2 = XYZ_LINEAR_INTERPOLATION(TEX2D(tex_co + dx).rgb, TEX2D(tex_co + dx + dy).rgb, curve_x); // mod
#	endif

	/* Variant- specific implementation: */
	if(true)
	{
#		if CFG_DEBUG_HALFVIEW
		if(pix_co.x < rubyInputSize.x/2)
#		else	
		if(true)
#		endif
		{
			col = XYZ_LINEAR_INTERPOLATION(col, col2, curve_distance(dist.x, SHARPNESS_H));
			col = XYZ_POW(col, XYZ_VECTOR3_T(TARGET_GAMMA_INPUT / (DILATION + 1.0)));
	
			float mask   = 1.0 - MASK_STRENGTH;
			XYZ_VECTOR2_T mod_fac = XYZ_FLOOR( XYZ_RES_vTexCoord * outsize.xy * SourceSize.xy / ( rubyInputSize.xy * XYZ_VECTOR2_T(MASK_SIZE, MASK_DOT_HEIGHT * MASK_SIZE) ) );
			int dot_no   = X_INT( XYZ_MOD( (mod_fac.y + XYZ_MOD(mod_fac.x, 2.0) * MASK_STAGGER) / MASK_DOT_WIDTH, 3.0) );
			XYZ_VECTOR3_T mask_weight = XYZ_VECTOR3_T(1.0,  1.0, 1.0);
	
			if (dot_no == 0) {
				mask_weight = XYZ_VECTOR3_T(0.44, 1.07, 1.07);
			}
			else
			if (dot_no == 1) {
				mask_weight = XYZ_VECTOR3_T(1.07, 0.40, 1.07);
	
			}
			else {
				mask_weight = XYZ_VECTOR3_T(1.06, 1.06, 0.40);
			}
	
			col2 = col.rgb;
			
			col *= mask_weight;
			col  = XYZ_POW(col, XYZ_VECTOR3_T(1.0 / TARGET_GAMMA_OUTPUT));
	
			XYZ_RES_FragColor = XYZ_VECTOR4_T(col * TARGET_BRIGHT_BOOST, 1.0);
		}
#		if CFG_DEBUG_HALFVIEW
		else
		{
			col = XYZ_POW(col, XYZ_VECTOR3_T(DEBUG_HALFVIEW_GAMMA_INPUT / (DILATION + 1.0)));
			col  = XYZ_POW(col, XYZ_VECTOR3_T(1.0 / DEBUG_HALFVIEW_GAMMA_OUTPUT));
	
			XYZ_RES_FragColor = XYZ_VECTOR4_T(col * DEBUG_HALFVIEW_BRIGHT_BOOST, 1.0);		
		}
#		endif
	}
	/* Variant- specific implementation: done */
}
#endif
