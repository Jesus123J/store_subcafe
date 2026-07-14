package com.thiago.gestionbodega.modules.integracion.ft;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class FinancialTrackerProperties {
    private boolean enabled = false;
    private String url;
    private String user;
    private String password;

    /** ID del service_concept en FT que representa "consumo de bodega". */
    private int serviceConceptId = 1;

    /** Dia del mes siguiente en que se descuenta el abono (1-28). */
    private int diaDescuento = 5;
}
