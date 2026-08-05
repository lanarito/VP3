/*
  Base Desmontable y Ajustable para Soporte de Microscopio
  Diseñado para caño estructural cuadrado de 30mm x 30mm.
  Cuenta con una base de 60mm x 60mm y un cuello de 50mm de altura.
  El cuello utiliza un sistema de abrazadera por presión (clamp) 
  con tornillo M6 para eliminar toda oscilación del caño.
*/

// --- PARÁMETROS AJUSTABLES ---
tamanio_cano = 30;         // Ancho del caño (30mm para 3x3 cm)
tolerancia_base = 0.25;    // Ajuste estrecho para minimizar oscilaciones (en mm)
alto_cuello = 50;          // Altura del cuello de retención (50mm)
espesor_pared_cuello = 5;  // Espesor del plástico del cuello
espesor_base = 6;          // Grosor de la placa base
tamanio_base = 60;         // Dimensiones de la base (60mm x 60mm)

// Tornillo de apriete (M6)
diametro_tornillo_m6 = 6.4;  // Diámetro del pasador del tornillo M6 (con tolerancia)
ancho_tuerca_m6 = 10.2;      // Ancho entre caras planas de la tuerca M6
espesor_tuerca_m6 = 5.2;     // Espesor de la tuerca M6

// Agujeros de fijación a la mesa (opcionales)
agujeros_fijacion = true;    // true para habilitar agujeros en las esquinas
diametro_fijacion = 4.5;     // Diámetro para tornillos M4 o similares
diametro_avellanado = 8.5;   // Para ocultar la cabeza del tornillo

// Calidad de curvas
$fn = 100;

// --- CÓDIGO DEL MODELO ---

module hexagono(ancho_caras, altura) {
    diametro_vertices = ancho_caras / cos(30);
    cylinder(d = diametro_vertices, h = altura, center = true, $fn = 6);
}

module base_soporte() {
    ancho_externo = tamanio_cano + tolerancia_base + (espesor_pared_cuello * 2);
    ancho_interno = tamanio_cano + tolerancia_base;
    
    difference() {
        union() {
            // 1. Placa Base cuadrada (60mm x 60mm)
            translate([0, 0, espesor_base / 2])
                cube([tamanio_base, tamanio_base, espesor_base], center = true);
            
            // 2. Cuello vertical de 50mm de alto
            translate([0, 0, alto_cuello / 2])
                cube([ancho_externo, ancho_externo, alto_cuello], center = true);
            
            // 3. Orejas de la abrazadera (bloques laterales para pasar el tornillo M6)
            // Se ubican en la cara frontal donde se corta el cuello para apretar
            translate([0, (ancho_externo / 2) + 4.5, (alto_cuello + espesor_base) / 2])
                cube([22, 9, 20], center = true);
        }
        
        // --- CORTES ---
        
        // A. Hueco para el caño estructural 30x30mm (pasa de largo por el cuello y la base)
        translate([0, 0, (alto_cuello + 10) / 2])
            cube([ancho_interno, ancho_interno, alto_cuello + 20], center = true);
        
        // B. Ranura vertical para el clamping (corta una pared del cuello para que sea flexible y pueda apretar)
        translate([0, (ancho_externo / 2), (alto_cuello + espesor_base) / 2])
            cube([2, espesor_pared_cuello * 2 + 10, alto_cuello + 10], center = true);
            
        // C. Agujero pasante para el tornillo M6 de apriete (cruza las dos orejas horizontalmente)
        translate([0, (ancho_externo / 2) + 4.5, (alto_cuello + espesor_base) / 2])
            rotate([0, 90, 0])
            cylinder(d = diametro_tornillo_m6, h = 30, center = true);
            
        // D. Alojamiento hexagonal para la tuerca M6 en una de las orejas (evita que gire al apretar)
        translate([7, (ancho_externo / 2) + 4.5, (alto_cuello + espesor_base) / 2])
            rotate([0, 90, 0])
            hexagono(ancho_tuerca_m6, espesor_tuerca_m6 + 0.2);
            
        // E. Cavidad cilíndrica para ocultar la cabeza del tornillo M6 en la otra oreja
        translate([-7, (ancho_externo / 2) + 4.5, (alto_cuello + espesor_base) / 2])
            rotate([0, 90, 0])
            cylinder(d = 11, h = 8, center = true);
            
        // F. Agujeros de fijación en las esquinas de la base (con avellanado para tornillo plano)
        if (agujeros_fijacion) {
            dist_agujeros = (tamanio_base / 2) - 7;
            for (x = [-dist_agujeros, dist_agujeros]) {
                for (y = [-dist_agujeros, dist_agujeros]) {
                    // Evitamos hacer agujero si choca con la zona del cuello
                    if (abs(x) > (ancho_externo / 2) || y < -(ancho_externo / 2)) {
                        translate([x, y, -0.5]) {
                            // Agujero pasante
                            cylinder(d = diametro_fijacion, h = espesor_base + 2);
                            // Avellanado superior
                            translate([0, 0, espesor_base - 2])
                                cylinder(d1 = diametro_fijacion, d2 = diametro_avellanado, h = 2.5);
                        }
                    }
                }
            }
        }
    }
}

// Renderizar la base
base_soporte();
