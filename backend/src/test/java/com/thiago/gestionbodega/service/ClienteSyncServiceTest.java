package com.thiago.gestionbodega.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;

/** Prueba de la heuristica que separa fullName (APELLIDOS NOMBRES) de FinantialTracker. */
class ClienteSyncServiceTest {

    private static void check(String full, String apellidos, String nombres) {
        assertArrayEquals(new String[]{apellidos, nombres}, ClienteSyncService.separarNombre(full), full);
    }

    @Test
    void nombresSimples() {
        check("ABANTO CARRION EVELYN MERY", "ABANTO CARRION", "EVELYN MERY");
        check("AGUSTINI RUIZ ROBERTO", "AGUSTINI RUIZ", "ROBERTO");
        check("ACUÑA AUCCAHUASI MELISSA WENDY", "ACUÑA AUCCAHUASI", "MELISSA WENDY");
    }

    @Test
    void apellidosCompuestos() {
        check("ACOSTA DEL POZO ERICK ALBERTO", "ACOSTA DEL POZO", "ERICK ALBERTO");
        check("ALIPAZAGA DEL CASTILLO GISSELA", "ALIPAZAGA DEL CASTILLO", "GISSELA");
        check("DE LA CRUZ QUISPE JUAN", "DE LA CRUZ QUISPE", "JUAN");
    }

    @Test
    void apellidoDeCasada() {
        check("BENAVENTE MONTORO DE RETO ZOILA PATRICIA", "BENAVENTE MONTORO DE RETO", "ZOILA PATRICIA");
        check("ARANA DE MORALES EMMA ELENA", "ARANA DE MORALES", "EMMA ELENA");
    }

    @Test
    void particulaEnElNombre() {
        check("BARRUETO ARANA ALEJANDRA DEL PILAR", "BARRUETO ARANA", "ALEJANDRA DEL PILAR");
    }

    @Test
    void casosDegenerados() {
        check("PEREZ", "PEREZ", "");
        check("PEREZ JUAN", "PEREZ", "JUAN");
    }
}
