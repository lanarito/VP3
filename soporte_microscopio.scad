/*
  Soporte Deslizable para Microscopio (Versión Corregida)
  Diseñado para caño estructural cuadrado de 30mm x 30mm.
  Incluye un cilindro vertical integrado de 60mm de diámetro interno
  apoyado directamente sobre la cama de impresión junto al anillo cuadrado,
  evitando partes en el aire y voladizos (sin plato ni labio inferior).
*/

// --- PARÁMETROS AJUSTABLES ---
// Caño estructural
tamanio_cano = 30;         // Tamaño del caño (30mm para caño de 3x3 cm)
tolerancia_cano = 0.6;     // Juego para que deslice suavemente (en mm)

// Plataforma del microscopio (Cilindro vertical porta-microscopio)
diametro_interno_micro = 60; // Diámetro interior donde entra el microscopio (60mm)
espesor_pared_micro = 5;     // Espesor de la pared del cilindro del microscopio

// Cuerpo del soporte
espesor_pared = 5;         // Espesor de las paredes del anillo cuadrado
alto_soporte = 40;         // Altura de la pieza deslizante y del cilindro

// Tornillo de ajuste (M8)
diametro_tornillo = 8.5;   // Agujero para tornillo M8 (con tolerancia)
ancho_tuerca_plana = 13.2; // Ancho entre caras de tuerca M8 (con tolerancia)
espesor_tuerca = 6.8;      // Espesor de la tuerca M8 (con tolerancia)

// Tipo de pieza a renderizar (para exportar)
part = "all"; // ["all": Todo junto, "slider": Solo el soporte, "knob": Solo la perilla]

// Calidad de curvas
$fn = 100;

// --- CÓDIGO DEL MODELO ---

module hexagono(ancho_caras, altura) {
    diametro_vertices = ancho_caras / cos(30);
    cylinder(d = diametro_vertices, h = altura, center = true, $fn = 6);
}

module perilla() {
    difference() {
        // Cuerpo exterior de la perilla
        union() {
            cylinder(d = 32, h = 12, center = true);
            for (a = [0 : 60 : 360]) {
                rotate([0, 0, a])
                    translate([16, 0, 0])
                    cylinder(d = 8, h = 12, center = true);
            }
        }
        
        // Alojamiento para la cabeza hexagonal del tornillo M8
        translate([0, 0, 3])
            hexagono(ancho_tuerca_plana, 7);
            
        // Agujero pasante para la rosca del tornillo
        cylinder(d = diametro_tornillo, h = 15, center = true);
    }
}

module slider() {
    ancho_externo = tamanio_cano + tolerancia_cano + (espesor_pared * 2);
    ancho_interno = tamanio_cano + tolerancia_cano;
    
    // Posición del cilindro del microscopio para que sea tangente por dentro
    // y se fusione perfectamente con la pared exterior del anillo cuadrado
    centro_cilindro_y = (ancho_externo / 2) + (diametro_interno_micro / 2);
    
    difference() {
        union() {
            // 1. Cuerpo principal (Anillo cuadrado para el caño)
            cube([ancho_externo, ancho_externo, alto_soporte], center = true);
            
            // 2. Cilindro porta-microscopio integrado verticalmente (apoyado en la cama)
            translate([0, centro_cilindro_y, 0])
                cylinder(d = diametro_interno_micro + (espesor_pared_micro * 2), h = alto_soporte, center = true);
            
            // 3. Soporte/Saliente para la tuerca de ajuste en la parte trasera
            translate([0, -((ancho_externo / 2) + 5), 0])
                cube([22, 10, 24], center = true);
        }
        
        // --- CORTES / HUECOS ---
        
        // A. Hueco interno del cilindro porta-microscopio (diámetro 60mm pasante, sin labio ni plato)
        translate([0, centro_cilindro_y, 0])
            cylinder(d = diametro_interno_micro, h = alto_soporte + 2, center = true);
        
        // B. Hueco para el caño estructural 30x30mm
        cube([ancho_interno, ancho_interno, alto_soporte + 2], center = true);
        
        // C. Agujero pasante para el tornillo de ajuste trasero
        translate([0, -((ancho_externo / 2) + 12), 0])
            rotate([90, 0, 0])
            cylinder(d = diametro_tornillo, h = 30, center = true);
            
        // D. Ranura de inserción vertical para la tuerca M8
        translate([0, -(ancho_externo / 2) - espesor_pared + (espesor_tuerca / 2) + 1.5, (alto_soporte / 4)])
            cube([ancho_tuerca_plana / cos(30), espesor_tuerca, alto_soporte / 2 + 0.1], center = true);
        
        // Cámara de alojamiento de la tuerca alineada con el tornillo
        translate([0, -(ancho_externo / 2) - espesor_pared + (espesor_tuerca / 2) + 1.5, 0])
            rotate([90, 90, 0])
            hexagono(ancho_tuerca_plana, espesor_tuerca + 0.2);
    }
}

// --- SELECCIÓN DE PIEZA A MOSTRAR ---
if (part == "all") {
    slider();
    
    // Posiciona la perilla al costado para imprimir todo junto
    translate([diametro_interno_micro + 15, 0, - (alto_soporte / 2) + 6])
        perilla();
} else if (part == "slider") {
    slider();
} else if (part == "knob") {
    perilla();
}
