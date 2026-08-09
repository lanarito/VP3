/*
  Guardamonte Orgánico e Integrado para Rifle Kafema Cal. 4.5
  Diseñado para reemplazo por impresión 3D basado en las fotos originales del rifle real.
  Este diseño utiliza extrusión de perfil lateral 2D e intersección tridimensional
  para lograr bordes totalmente redondeados y orgánicos que copian la culata y el render.
*/

// --- PARÁMETROS AJUSTABLES (en mm) ---
distancia_centros = 63.0;     // Distancia entre el centro del tornillo frontal Allen y el trasero de madera
ancho_guardamonte = 14.5;     // Ancho total de la pieza (se adapta al ancho de la culata)
radio_redondeado_bordes = 2.0;// Radio de redondeado de los bordes laterales (Z) para aspecto orgánico

// Espesores de la Pieza
espesor_pestana_front = 9.5;  // Espesor del bloque delantero (suficiente para embutir el tornillo Allen y arandela)
espesor_pestana_rear = 3.5;   // Espesor de la pestaña trasera que copia la empuñadura
espesor_pared_arco = 3.5;     // Espesor del arco protector del gatillo

// Ángulo de inclinación de la empuñadura trasera
angulo_pestana_rear = 14.0;    // Ángulo de inclinación de la culata en la empuñadura (grados)

// Dimensiones del Arco (Espacio libre para el gatillo)
alto_interno = 24.0;          // Profundidad interna libre del arco
largo_interno = 36.0;         // Largo interno libre del arco
desplazamiento_arco = 16.0;   // Distancia desde el centro del tornillo frontal Allen hasta el inicio del arco

// Tornillo Frontal Allen (Fijación principal de culata)
diametro_tornillo_front = 6.2; // Diámetro de paso de la rosca M6
diametro_cabeza_front = 11.2;  // Diámetro del alojamiento de la cabeza y arandela
profundidad_cabeza_front = 6.5;// Profundidad de la cavidad para embutir la cabeza

// Tornillo Trasero (De madera)
diametro_tornillo_rear = 3.5;  // Diámetro del tornillo trasero para madera
diametro_avellanado_rear = 7.0;// Diámetro del avellanado para la cabeza del tornillo trasero
profundidad_avellanado = 2.0;  // Profundidad del avellanado trasero

// Tornillo de Seguridad Frontal Opcional (Para evitar que la punta delantera se levante)
tornillo_seguridad_front = true; // Habilitar agujero para tornillo pequeño de madera en la punta
diametro_tornillo_seg_front = 3.0;
diametro_avellanado_seg_front = 6.0;
profundidad_avellanado_seg_front = 1.5;
distancia_seg_front = -18.0;   // Distancia desde el tornillo Allen principal hacia adelante

// Calidad de Curvas
$fn = 120;

// --- MODELADO ---

// 1. Perfil 2D del Guardamonte (Vista Lateral)
module perfil_2d() {
    // Definimos radios del arco interior para que sea asimétrico (más alto al frente)
    r1_in = alto_interno / 2;
    r2_in = (alto_interno * 0.8) / 2;
    
    // Centros para el contorno exterior del arco (van hasta el inicio de la pestaña trasera)
    c1_x = desplazamiento_arco + r1_in;
    c1_y = -alto_interno + r1_in;
    
    c2_x_out = desplazamiento_arco + largo_interno + 2;
    c2_y_out = -espesor_pestana_rear/2;
    
    // Centros para el hueco interior (termina antes para no cortar la pestaña)
    c2_x_in = desplazamiento_arco + largo_interno - r2_in;
    c2_y_in_real = -(alto_interno * 0.8) + r2_in;

    difference() {
        union() {
            // A. Bloque Delantero (Espeso para embutir el tornillo Allen)
            polygon([
                [-25, 0],
                [desplazamiento_arco + 5, 0],
                [desplazamiento_arco + 5, -espesor_pestana_front],
                [-20, -espesor_pestana_front],
                [-25, -3.0]
            ]);
            
            // B. Pestaña Trasera (Curvada, copia la empuñadura)
            hull() {
                translate([desplazamiento_arco + largo_interno + 2, -espesor_pestana_rear/2])
                    circle(d = espesor_pestana_rear);
                translate([distancia_centros - 5, 2.0])
                    circle(d = espesor_pestana_rear);
                translate([distancia_centros + 10, 7.5])
                    circle(d = espesor_pestana_rear);
                translate([distancia_centros + 25, 12.0])
                    circle(d = espesor_pestana_rear);
            }
            
            // C. Cuerpo Exterior del Arco (Va de c1 a c2_out)
            hull() {
                translate([c1_x, c1_y])
                    circle(r = r1_in + espesor_pared_arco);
                translate([c2_x_out, c2_y_out])
                    circle(r = r2_in + espesor_pared_arco);
            }
        }
        
        // D. Restar el Hueco del Gatillo (Va de c1 a c2_in)
        hull() {
            translate([c1_x, c1_y])
                circle(r = r1_in);
            translate([c2_x_in, c2_y_in_real])
                circle(r = r2_in);
        }
        
        // E. Restar la zona superior de la culata (para que asiente al ras)
        polygon([
            [-50, 100],
            [120, 100],
            [120, 20],
            [distancia_centros + 35, 14.0],
            [distancia_centros + 10, 7.5 + espesor_pestana_rear/2],
            [distancia_centros - 5, 2.0 + espesor_pestana_rear/2],
            [desplazamiento_arco + largo_interno + 2, 0],
            [-50, 0]
        ]);
    }
}

// 2. Bloque de Redondeado Lateral (Cápsula 3D extruida en X)
module cortador_redondeado_3d() {
    rotate([0, 90, 0])
    linear_extrude(height = 300, center = true) {
        offset(r = radio_redondeado_bordes)
        square([ancho_guardamonte - 2*radio_redondeado_bordes, 150 - 2*radio_redondeado_bordes], center = true);
    }
}

// 3. Modelo 3D con Perforaciones y Bordes Redondeados
module guardamonte_completo() {
    difference() {
        // Intersecamos la extrusión con el cortador redondeado para tener bordes orgánicos en Z
        intersection() {
            linear_extrude(height = ancho_guardamonte, center = true)
                perfil_2d();
                
            cortador_redondeado_3d();
        }
            
        // --- PERFORACIONES (CORTES EN 3D) ---
        
        // A. Agujero para Tornillo Allen Frontal (Eje Y, vertical en x = 0)
        // Pasamos el cilindro sin rotaciones que cancelen la orientación.
        // Un cilindro en OpenSCAD va en el eje Z por defecto, por lo que rotar 90 en X lo alinea en Y.
        translate([0, -espesor_pestana_front - 1, 0])
            rotate([90, 0, 0])
            cylinder(d = diametro_tornillo_front, h = espesor_pestana_front + 2);
            
        // Alojamiento de la cabeza Allen (avellanado/receso cilíndrico)
        translate([0, -espesor_pestana_front - 0.1, 0])
            rotate([90, 0, 0])
            cylinder(d = diametro_cabeza_front, h = profundidad_cabeza_front + 0.1);
            
        // B. Tornillo de Seguridad Frontal Opcional (en la punta de la pieza)
        if (tornillo_seguridad_front) {
            translate([distancia_seg_front, -espesor_pestana_front - 1, 0])
                rotate([90, 0, 0])
                cylinder(d = diametro_tornillo_seg_front, h = espesor_pestana_front + 2);
                
            translate([distancia_seg_front, -espesor_pestana_front - 0.1, 0])
                rotate([90, 0, 0])
                cylinder(d1 = diametro_avellanado_seg_front, d2 = diametro_tornillo_seg_front, h = profundidad_avellanado_seg_front + 0.1);
        }
        
        // C. Tornillo Trasero Inclinado (Alineado con la pestaña trasera tildada)
        x_bisagra = desplazamiento_arco + largo_interno - 3;
        
        translate([x_bisagra, 0, 0])
        rotate([0, 0, angulo_pestana_rear])
        translate([-x_bisagra, 0, 0]) {
            // Agujero pasante para el tornillo trasero (rotado 90 en X para ir sobre Y)
            translate([distancia_centros, -espesor_pestana_rear - 1, 0])
                rotate([90, 0, 0])
                cylinder(d = diametro_tornillo_rear, h = espesor_pestana_rear + 2);
                
            // Avellanado cónico (rotado 90 en X)
            translate([distancia_centros, -espesor_pestana_rear - 0.1, 0])
                rotate([90, 0, 0])
                cylinder(d1 = diametro_avellanado_rear, d2 = diametro_tornillo_rear, h = profundidad_avellanado + 0.1);
        }
    }
}

// Centrar el guardamonte en el visualizador
translate([-distancia_centros/2, 0, 0])
    guardamonte_completo();
