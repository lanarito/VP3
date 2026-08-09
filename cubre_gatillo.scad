/*
  Guardamonte Paramétrico para Rifle Kafema Cal. 4.5
  Diseñado para reemplazo por impresión 3D basado en las fotos originales.
  Sujeción frontal mediante tornillo principal Allen de culata y sujeción trasera con tornillo de madera.
  La pestaña trasera incluye inclinación ajustable para copiar la curva de la culata (empuñadura).
*/

// --- PARÁMETROS AJUSTABLES (en mm) ---
distancia_centros = 63.0;     // Distancia entre el centro del tornillo frontal y el trasero
ancho_guardamonte = 14.5;     // Ancho total de la pieza (vista desde arriba)
espesor_pestanas = 3.5;       // Espesor de las pestañas de montaje (donde asientan los tornillos)
espesor_pared_arco = 3.2;     // Espesor de la pared del arco protector

// Inclinación de la culata en la parte trasera (empuñadura)
angulo_pestana_rear = 12.0;    // Ángulo de inclinación de la pestaña trasera (grados) para copiar la culata

// Dimensiones del Arco (Espacio para el gatillo)
alto_interno = 24.0;          // Altura interna libre del arco (profundidad para el gatillo)
largo_interno = 42.0;         // Largo interno libre del arco
desplazamiento_arco = 16.0;   // Distancia desde el centro del tornillo frontal hasta el inicio del arco

// Tornillo Frontal (De fijación de culata)
diametro_tornillo_front = 6.2; // Diámetro del pasador del tornillo frontal

// Tornillo Trasero (Para madera)
diametro_tornillo_rear = 3.5;  // Diámetro del tornillo para madera trasero
diametro_avellanado_rear = 7.0;// Diámetro del avellanado para la cabeza del tornillo trasero
profundidad_avellanado = 2.0;  // Profundidad del avellanado

// Calidad de Curvas
$fn = 120;

// --- CÓDIGO DEL MODELO ---

// 1. Pestaña Frontal (Plana)
module pestana_front_3d() {
    difference() {
        translate([0, -espesor_pestanas/2, 0])
        rotate([90, 0, 0])
        linear_extrude(height = espesor_pestanas, center = true) {
            hull() {
                translate([-(ancho_guardamonte/2 - 2), 0])
                    circle(d = ancho_guardamonte);
                translate([desplazamiento_arco + 5, 0])
                    circle(d = ancho_guardamonte);
            }
        }
        
        // Agujero para tornillo frontal
        translate([0, -espesor_pestanas - 1, 0])
            rotate([-90, 0, 0])
            cylinder(d = diametro_tornillo_front, h = espesor_pestanas + 2);
    }
}

// 2. Pestaña Trasera (Inclinada para seguir la empuñadura de madera)
module pestana_rear_tilted_3d() {
    x_bisagra = desplazamiento_arco + largo_interno - 3;
    
    translate([x_bisagra, 0, 0])
    rotate([0, 0, angulo_pestana_rear])
    translate([-x_bisagra, 0, 0]) {
        difference() {
            // Cuerpo de la pestaña trasera con solape hacia el arco
            translate([0, -espesor_pestanas/2, 0])
            rotate([90, 0, 0])
            linear_extrude(height = espesor_pestanas, center = true) {
                hull() {
                    translate([x_bisagra - 5, 0])
                        circle(d = ancho_guardamonte);
                    translate([distancia_centros + (ancho_guardamonte/2 - 2), 0])
                        circle(d = ancho_guardamonte);
                }
            }
            
            // Agujero pasante para el tornillo trasero (perpendicular a la pestaña inclinada)
            translate([distancia_centros, -espesor_pestanas - 1, 0])
                rotate([-90, 0, 0])
                cylinder(d = diametro_tornillo_rear, h = espesor_pestanas + 2);
                
            // Avellanado para el tornillo trasero
            translate([distancia_centros, -espesor_pestanas - 0.1, 0])
                rotate([-90, 0, 0])
                cylinder(d1 = diametro_avellanado_rear, d2 = diametro_tornillo_rear, h = profundidad_avellanado + 0.1);
        }
    }
}

// 3. Arco Protector (Extruido lateralmente para perfil curvo)
module arco_3d() {
    // Definimos radios del arco interior para que sea asimétrico (más alto al frente)
    r1_in = alto_interno / 2; // Radio frontal interior
    r2_in = (alto_interno * 0.8) / 2; // Radio trasero interior
    
    // Centros de los círculos generadores del arco
    c1_x = desplazamiento_arco + r1_in;
    c1_y = -alto_interno + r1_in;
    
    c2_x = desplazamiento_arco + largo_interno - r2_in;
    c2_y = -(alto_interno * 0.8) + r2_in;

    // Extruimos el perfil lateral de forma centrada respecto al ancho del guardamonte
    translate([0, 0, 0])
    rotate([90, 0, 0]) // Rotamos para que la extrusión sea lateral
    linear_extrude(height = ancho_guardamonte, center = true) {
        difference() {
            // Cuerpo Exterior del Arco
            hull() {
                translate([c1_x, c1_y])
                    circle(r = r1_in + espesor_pared_arco);
                translate([c2_x, c2_y])
                    circle(r = r2_in + espesor_pared_arco);
            }
            
            // Hueco Interior
            hull() {
                translate([c1_x, c1_y])
                    circle(r = r1_in);
                translate([c2_x, c2_y])
                    circle(r = r2_in);
            }
            
            // Cortar la mitad superior (todo lo que esté arriba de y = -espesor_pestanas para acoplarse)
            translate([desplazamiento_arco - 20, -espesor_pestanas])
                square([largo_interno + 40, alto_interno + 20]);
        }
    }
}

// 4. Ensamblaje Completo
module guardamonte_completo() {
    pestana_front_3d();
    pestana_rear_tilted_3d();
    arco_3d();
}

// Centrar el guardamonte en el visualizador
translate([-distancia_centros/2, 0, 0])
    guardamonte_completo();
