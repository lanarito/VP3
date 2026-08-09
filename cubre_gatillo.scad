/*
  Guardamonte Orgánico e Integrado para Rifle Kafema Cal. 4.5
  Diseñado para reemplazo por impresión 3D basado en las fotos originales del rifle real.
*/

// --- PARÁMETROS AJUSTABLES (en mm) ---
distancia_centros = 63.0;     // Distancia entre el centro del tornillo frontal Allen y el trasero de madera
ancho_guardamonte = 14.5;     // Ancho total de la pieza (se adapta al ancho de la culata)
radio_redondeado_bordes = 2.0;// Radio de redondeado de los bordes laterales (Z)

// Espesores de la Pieza
espesor_pestana_front = 9.5;  // Espesor del bloque delantero
espesor_pestana_rear = 3.5;   // Espesor de la cinta/pestaña trasera
espesor_techo_arco = 3.5;     // Espesor del techo plano superior del arco
espesor_pared_arco = 3.5;     // Espesor de la pared del arco del gatillo

// Dimensiones del Arco (Espacio libre para el gatillo)
desplazamiento_arco = 16.0;   // Distancia desde el centro del tornillo frontal Allen hasta el inicio del arco

// Tornillo Frontal Allen (Fijación principal de culata)
diametro_tornillo_front = 6.2; // Diámetro de paso de la rosca M6
diametro_cabeza_front = 11.2;  // Diámetro del alojamiento de la cabeza y arandela
profundidad_cabeza_front = 6.5;// Profundidad de la cavidad para embutir la cabeza

// Tornillo Trasero (De madera, pasante lateral de lado a lado)
diametro_tornillo_rear = 3.5;  // Diámetro del tornillo trasero para madera
diametro_avellanado_rear = 7.0;// Diámetro del avellanado para la cabeza del tornillo trasero
profundidad_avellanado = 1.8;  // Profundidad del avellanado trasero

// Tornillo de Seguridad Frontal Opcional
tornillo_seguridad_front = true;
diametro_tornillo_seg_front = 3.0;
diametro_avellanado_seg_front = 6.0;
profundidad_avellanado_seg_front = 1.5;
distancia_seg_front = -18.0;

// Calidad de Curvas
$fn = 100;

// --- MODELADO ---

// 1. Perfil 2D del Guardamonte (Vista Lateral Fiel al Rifle Real)
module perfil_base_2d() {
    // Doble offset suave para empalmes curvos de alta calidad
    offset(r = 1.0, $fn = 80) offset(r = -1.0, $fn = 80)
    difference() {
        union() {
            // A. Nose delantero redondeado
            translate([-20, -espesor_pestana_front/2])
                circle(d = espesor_pestana_front);
            
            // Bloque Delantero (x = -20 a x = 16)
            polygon([
                [-20, 0],
                [16, 0],
                [16, -espesor_pestana_front],
                [-20, -espesor_pestana_front]
            ]);
            
            // B. Techo Superior Continuo (x = 16 a x = 42, 100% SÓLIDO AL RAS DE LA MADERA)
            polygon([
                [16, 0],
                [42, 0],
                [42, -espesor_techo_arco],
                [16, -espesor_techo_arco]
            ]);
            
            // C. Anillo Exterior del Arco del Gatillo que cuelga hacia abajo
            hull() {
                translate([27.0, -12.0])
                    circle(r = 12.0);
                translate([37.0, -6.5])
                    circle(d = 7.0);
            }
            
            // D. Pestaña Trasera (Cinta delgada de 3.5mm que envuelve el manillar)
            hull() {
                translate([37.0, -5.0])
                    circle(d = 6.0);
                translate([45.0, -4.5])
                    circle(d = 5.0);
                translate([distancia_centros, -8.5]) // x = 63.0 (Tornillo de madera)
                    circle(d = 8.0);
                translate([distancia_centros + 15, -19.75]) // x = 78.0
                    circle(d = 4.0);
                translate([distancia_centros + 27, -33.75]) // x = 90.0
                    circle(d = 3.5);
            }
        }
        
        // E. Hueco del Gatillo (Bolsillo inferior: termina exactamente en y = -3.5, JAMÁS corta el techo superior)
        hull() {
            translate([27.0, -12.0])
                circle(r = 8.5);
            translate([31.0, -8.5])
                circle(r = 5.0);
        }
        
        // F. Superficie de Asiento con la Culata de Madera (Corte superior al ras)
        polygon([
            [-50, 100],
            [120, 100],
            [120, -32.0],
            [90, -32.0],
            [78, -18.0],
            [distancia_centros, -6.0], // x = 63
            [42, 0],
            [-50, 0]
        ]);
    }
}

// 2. Redondeado Lateral Orgánico 3D (Bordes redondeados suaves en Z)
module cortador_redondeado_3d() {
    rotate([0, 90, 0])
    linear_extrude(height = 300, center = true) {
        offset(r = radio_redondeado_bordes)
        square([ancho_guardamonte - 2*radio_redondeado_bordes, 150 - 2*radio_redondeado_bordes], center = true);
    }
}

// 3. Modelo 3D Final Integrado
module guardamonte_completo() {
    difference() {
        // Extrusión 3D con bordes orgánicos redondeados
        intersection() {
            linear_extrude(height = ancho_guardamonte, center = true)
                perfil_base_2d();
                
            cortador_redondeado_3d();
        }
            
        // --- PERFORACIONES (CORTES EN 3D) ---
        
        // A. Agujero para Tornillo Allen Frontal (Eje Y, vertical en x = 0, hacia arriba)
        translate([0, -espesor_pestana_front - 1, 0])
            rotate([-90, 0, 0])
            cylinder(d = diametro_tornillo_front, h = espesor_pestana_front + 2);
            
        // Alojamiento de la cabeza Allen
        translate([0, -espesor_pestana_front - 0.1, 0])
            rotate([-90, 0, 0])
            cylinder(d = diametro_cabeza_front, h = profundidad_cabeza_front + 0.1);
            
        // B. Tornillo de Seguridad Frontal Opcional
        if (tornillo_seguridad_front) {
            translate([distancia_seg_front, -espesor_pestana_front - 1, 0])
                rotate([-90, 0, 0])
                cylinder(d = diametro_tornillo_seg_front, h = espesor_pestana_front + 2);
                
            translate([distancia_seg_front, -espesor_pestana_front - 0.1, 0])
                rotate([-90, 0, 0])
                cylinder(d1 = diametro_avellanado_seg_front, d2 = diametro_tornillo_seg_front, h = profundidad_avellanado_seg_front + 0.1);
        }
        
        // C. Tornillo Trasero Horizontal (Eje Z, pasante lateral en x = 63, y = -8.5)
        translate([distancia_centros, -8.5, 0])
            cylinder(d = diametro_tornillo_rear, h = ancho_guardamonte + 2, center = true);
            
        // Avellanado cónico derecho (Z positivo)
        translate([distancia_centros, -8.5, ancho_guardamonte/2 - profundidad_avellanado])
            cylinder(d1 = diametro_tornillo_rear, d2 = diametro_avellanado_rear, h = profundidad_avellanado + 0.1);
            
        // Avellanado cónico izquierdo (Z negativo)
        translate([distancia_centros, -8.5, -ancho_guardamonte/2 - 0.1])
            cylinder(d1 = diametro_avellanado_rear, d2 = diametro_tornillo_rear, h = profundidad_avellanado + 0.1);
    }
}

// Centrar el guardamonte en el visualizador
translate([-distancia_centros/2, 0, 0])
    guardamonte_completo();
