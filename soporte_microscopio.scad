/*
  Soporte Deslizable para Microscopio con Horquilla Articulada (Versión Final Corregida)
  Diseñado para caño estructural cuadrado de 30mm x 30mm.
  Cuenta con una horquilla frontal redondeada para sujetar directamente
  el brazo articulado del microscopio.
  Incluye una perilla de ajuste M8 más fina y estilizada (8mm de grosor)
  y un soporte de tuerca trasero reforzado (pared de 9.5mm de plástico) para máxima resistencia.
*/

// --- PARÁMETROS AJUSTABLES ---
// Caño estructural
tamanio_cano = 30;         // Tamaño del caño (30mm para caño de 3x3 cm)
tolerancia_cano = 1.8;     // Juego para que deslice con total libertad (en mm, antes 0.6)

// Horquilla de articulación (Medidas del ojo del brazo del microscopio)
ancho_interno_horquilla = 18.6; // Espacio libre para el ojo del brazo (18mm + tolerancia)
espesor_oreja = 5;              // Grosor de las paredes de la horquilla
alto_horquilla = 20;            // Diámetro exterior de la punta redondeada (20mm)
distancia_eje = 12;             // Distancia desde el caño al centro del perno (en mm)

// Perno de articulación (M6)
diametro_pasador_m6 = 6.4;      // Agujero para tornillo M6
ancho_tuerca_m6 = 10.3;         // Ancho entre caras de tuerca M6
espesor_tuerca_m6 = 5.2;        // Espesor de la tuerca M6
profundidad_tuerca_m6 = 3.5;    // Profundidad del encastre para la tuerca M6

// Cuerpo del soporte
espesor_pared = 5;         // Espesor de las paredes del anillo cuadrado
alto_soporte = 40;         // Altura de la pieza deslizante

// Tornillo de ajuste al caño (M8)
diametro_tornillo_m8 = 8.5;   // Agujero para tornillo M8 (con tolerancia)
ancho_tuerca_m8 = 13.2;       // Ancho entre caras de tuerca M8 (con tolerancia)
espesor_tuerca_m8 = 6.8;      // Espesor de la tuerca M8 (con tolerancia)
alto_perilla_m8 = 8;          // Grosor de la perilla de ajuste (más delgada, antes 12mm)
profundidad_cabeza_m8 = 5.5;  // Profundidad para embutir la cabeza del tornillo M8

// Tipo de pieza a renderizar (para exportar)
part = "all"; // ["all": Todo junto, "slider": Solo el soporte, "knob": Solo la perilla M8]

// Calidad de curvas
$fn = 100;

// --- CÓDIGO DEL MODELO ---

module hexagono(ancho_caras, altura) {
    diametro_vertices = ancho_caras / cos(30);
    cylinder(d = diametro_vertices, h = altura, center = true, $fn = 6);
}

module perilla_m8() {
    difference() {
        // Cuerpo exterior de la perilla M8 para ajuste del caño (delgada)
        union() {
            cylinder(d = 32, h = alto_perilla_m8, center = true);
            for (a = [0 : 60 : 360]) {
                rotate([0, 0, a])
                    translate([16, 0, 0])
                    cylinder(d = 8, h = alto_perilla_m8, center = true);
            }
        }
        
        // Alojamiento para la cabeza hexagonal del tornillo M8 (queda embutido)
        translate([0, 0, (alto_perilla_m8 / 2) - (profundidad_cabeza_m8 / 2) + 0.1])
            hexagono(ancho_tuerca_m8, profundidad_cabeza_m8 + 0.2);
            
        // Agujero pasante para la rosca del tornillo
        cylinder(d = diametro_tornillo_m8, h = alto_perilla_m8 + 2, center = true);
    }
}

module slider() {
    ancho_externo = tamanio_cano + tolerancia_cano + (espesor_pared * 2);
    ancho_interno = tamanio_cano + tolerancia_cano;
    
    Y_eje = (ancho_externo / 2) + distancia_eje;
    ancho_total_horquilla = ancho_interno_horquilla + (espesor_oreja * 2);
    x_oreja_der = (ancho_interno_horquilla / 2) + (espesor_oreja / 2);
    x_oreja_izq = -x_oreja_der;
    
    difference() {
        union() {
            // 1. Cuerpo principal (Anillo cuadrado para el caño)
            cube([ancho_externo, ancho_externo, alto_soporte], center = true);
            
            // 2. Horquilla: Oreja Izquierda
            translate([x_oreja_izq, 0, 0]) {
                translate([0, (ancho_externo / 2) + (distancia_eje / 2), 0])
                    cube([espesor_oreja, distancia_eje + 0.1, alto_horquilla], center = true);
                translate([0, Y_eje, 0])
                    rotate([0, 90, 0])
                    cylinder(d = alto_horquilla, h = espesor_oreja, center = true);
            }
            
            // 3. Horquilla: Oreja Derecha
            translate([x_oreja_der, 0, 0]) {
                translate([0, (ancho_externo / 2) + (distancia_eje / 2), 0])
                    cube([espesor_oreja, distancia_eje + 0.1, alto_horquilla], center = true);
                translate([0, Y_eje, 0])
                    rotate([0, 90, 0])
                    cylinder(d = alto_horquilla, h = espesor_oreja, center = true);
            }
            
            // 4. Soporte/Saliente reforzado para la tuerca de ajuste trasera (espesor aumentado a 13mm)
            translate([0, -((ancho_externo / 2) + 6.5), 0])
                cube([22, 13, 24], center = true);
        }
        
        // --- CORTES / HUECOS ---
        
        // A. Hueco para el caño estructural 30x30mm
        cube([ancho_interno, ancho_interno, alto_soporte + 2], center = true);
        
        // B. Agujero pasante M6 en la horquilla (eje X)
        translate([0, Y_eje, 0])
            rotate([0, 90, 0])
            cylinder(d = diametro_pasador_m6, h = ancho_total_horquilla + 2, center = true);
            
        // C. Encastre hexagonal para la tuerca M6 (Oreja Derecha)
        translate([ancho_total_horquilla/2 - profundidad_tuerca_m6/2 + 0.1, Y_eje, 0])
            rotate([0, 90, 0])
            hexagono(ancho_tuerca_m6, profundidad_tuerca_m6 + 0.2);
            
        // D. Encastre cilíndrico para la cabeza del tornillo M6 (Oreja Izquierda)
        translate([-ancho_total_horquilla/2 + profundidad_tuerca_m6/2 - 0.1, Y_eje, 0])
            rotate([0, 90, 0])
            cylinder(d = 10.5, h = profundidad_tuerca_m6 + 0.2, center = true);
        
        // E. Agujero pasante para el tornillo de ajuste trasero (M8 para el caño)
        translate([0, -((ancho_externo / 2) + 12), 0])
            rotate([90, 0, 0])
            cylinder(d = diametro_tornillo_m8, h = 30, center = true);
            
        // F. Ranura de inserción vertical para la tuerca M8 del caño
        translate([0, -(ancho_externo / 2) - espesor_pared + (espesor_tuerca_m8 / 2) + 1.5, (alto_soporte / 4)])
            cube([ancho_tuerca_m8 / cos(30), espesor_tuerca_m8, alto_soporte / 2 + 0.1], center = true);
        
        // Cámara de alojamiento de la tuerca M8 del caño
        translate([0, -(ancho_externo / 2) - espesor_pared + (espesor_tuerca_m8 / 2) + 1.5, 0])
            rotate([90, 90, 0])
            hexagono(ancho_tuerca_m8, espesor_tuerca_m8 + 0.2);
    }
}

// --- SELECCIÓN DE PIEZA A MOSTRAR ---
if (part == "all") {
    slider();
    
    // Posiciona la perilla M8 al costado para imprimir todo junto
    translate([ancho_interno_horquilla + 25, 0, - (alto_soporte / 2) + (alto_perilla_m8 / 2)])
        perilla_m8();
} else if (part == "slider") {
    slider();
} else if (part == "knob") {
    perilla_m8();
}
