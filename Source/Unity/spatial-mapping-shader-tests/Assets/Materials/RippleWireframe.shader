﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Shader made by Robert Kazimiroff based on 'Wireframe.shader'
// from HoloToolKit-Unity Repo by Microsoft at https://github.com/Microsoft/HoloToolkit-Unity
// Original 'Wireframe.shader' code Copyright (C) Microsoft. All rights reserved.
//

Shader "Surface Reconstruction/Ripple" 
{
	Properties
	{
		_BaseColor("Base color", Color) = (0.0, 0.0, 0.0, 1.0)
		_WireColor("Wire color", Color) = (1.0, 1.0, 1.0, 1.0)
		_WireThickness("Wire thickness", Range(0, 800)) = 100
		_TargetPosition("Ripple Start Position", Vector) = (0.0, 0.0, 0.0, 1.0)
		_StartTime("Start time, seconds", Range(0, 100)) = 5.0
		_RippleWidth("RippleWidth, m", Range(0.1, 3)) = 0.5
		_RippleSpeed("Ripple speed, m/s", Range(0.1, 3)) = 1
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			Offset 50, 100

			CGPROGRAM

			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#include "UnityCG.cginc"

			float4 _BaseColor;
			float4 _WireColor;
			float _WireThickness;
			float4 _TargetPosition;
			float _StartTime;
			float _RippleWidth;
			float _RippleSpeed;

			// Based on approach described in "Shader-Based Wireframe Drawing", http://cgg-journal.com/2008-2/06/index.html

			struct v2g 
			{
				float4 viewPos : SV_POSITION;
				float distToTarget : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert(appdata_base v) 
			{
                UNITY_SETUP_INSTANCE_ID(v);
				v2g o;
				o.viewPos = UnityObjectToClipPos(v.vertex);
				o.distToTarget = length(mul(unity_ObjectToWorld, v.vertex).xyz - _TargetPosition.xyz);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				return o;
			}

			// inverseW is to counter-act the effect of perspective-correct interpolation so that the lines look the same thickness
			// regardless of their depth in the scene.
			struct g2f 
			{
				float4 viewPos : SV_POSITION;
				float inverseW : TEXCOORD0;
				float3 dist : TEXCOORD1;
				float distToTarget : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
			};

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream) 
			{
				// Calculate the vectors that define the triangle from the input points.
				float2 point0 = i[0].viewPos.xy / i[0].viewPos.w;
				float2 point1 = i[1].viewPos.xy / i[1].viewPos.w;
				float2 point2 = i[2].viewPos.xy / i[2].viewPos.w;

				// Calculate the area of the triangle.
				float2 vector0 = point2 - point1;
				float2 vector1 = point2 - point0;
				float2 vector2 = point1 - point0;
				float area = abs(vector1.x * vector2.y - vector1.y * vector2.x);

				float wireScale = 800 - _WireThickness;

				// Output each original vertex with its distance to the opposing line defined
				// by the other two vertices.

				g2f o;

				o.viewPos = i[0].viewPos;
				o.inverseW = 1.0 / o.viewPos.w;
				o.dist = float3(area / length(vector0), 0, 0) * o.viewPos.w * wireScale;
				o.distToTarget = i[0].distToTarget;
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);
				triStream.Append(o);

				o.viewPos = i[1].viewPos;
				o.inverseW = 1.0 / o.viewPos.w;
				o.dist = float3(0, area / length(vector1), 0) * o.viewPos.w * wireScale;
				o.distToTarget = i[1].distToTarget;
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);
				triStream.Append(o);

				o.viewPos = i[2].viewPos;
				o.inverseW = 1.0 / o.viewPos.w;
				o.dist = float3(0, 0, area / length(vector2)) * o.viewPos.w * wireScale;
				o.distToTarget = i[2].distToTarget;
                UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);
				triStream.Append(o);
			}

			float4 frag(g2f i) : COLOR
			{
				// Calculate  minimum distance to one of the triangle lines, making sure to correct
				// for perspective-correct interpolation.
				float dist = min(i.dist[0], min(i.dist[1], i.dist[2])) * i.inverseW;

				// Make the intensity of the line very bright along the triangle edges but fall-off very
				// quickly.
				float I = exp2(-2 * dist * dist);

				//Numerical val for ripple will be the center of the ripple radius
				float rippleTravelDistance = (_Time.y - _StartTime) * _RippleSpeed - _RippleWidth / 2.0;

				// Fade out the alpha but not the color so we don't get any weird halo effects from
				// a fade to a different color.
				float4 color = (1 - I) * _BaseColor; 
				if (abs(i.distToTarget - rippleTravelDistance) < _RippleWidth)
					color = color + I *_WireColor * (1 - abs(i.distToTarget - rippleTravelDistance) / _RippleWidth );
				color.a = I;

				return color;
			}

			ENDCG
		}
	}
	
	FallBack "Diffuse"
}
