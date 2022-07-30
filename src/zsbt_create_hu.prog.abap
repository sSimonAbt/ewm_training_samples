*&---------------------------------------------------------------------*
*& Report zsbt_create_hu
*&---------------------------------------------------------------------*
*& Eingabe Lagerplatz
*& /scwm/cl_packing create HU
*& HU Ausgabe per Logging
*&---------------------------------------------------------------------*
REPORT zsbt_create_hu.

DATA: lo_packing         TYPE REF TO /scwm/cl_wm_packing,
      lo_log             TYPE REF TO /scwm/cl_log,
      huhdr              TYPE   /scwm/s_huhdr_int,
      huhdr_result       TYPE   /scwm/s_huhdr_int,
      ls_display_profile TYPE bal_s_prof.

PARAMETERS: p_lgnum TYPE /scwm/lgnum DEFAULT 'WU02',
            p_lgpla TYPE /scwm/lgpla DEFAULT 'GR-ZONE',
            ppmat   TYPE /sapapo/matnr DEFAULT 'ZRFR_PACK',
            p_save  TYPE abap_bool DEFAULT abap_true.

START-OF-SELECTION.

  /scwm/cl_tm=>set_lgnum( EXPORTING iv_lgnum = p_lgnum ).
  "Erstellen des Log Objektes
  lo_log = NEW /scwm/cl_log( iv_balobj       = 'ZSBT'
                             iv_balsubobj    = 'ZSBT_MUSTER_SCHULUNG' ).

  /scwm/cl_wm_packing=>get_instance( IMPORTING eo_instance = lo_packing ).

  lo_packing->init( EXPORTING iv_lgnum               = p_lgnum                  " Warehouse Number/Warehouse Complex
                    EXCEPTIONS OTHERS = 99 ).
  IF sy-subrc <> 0.
    "Fehler beim instanziieren der Packing Klasse
    MESSAGE e001(zsbt_ewm_muster) INTO DATA(lv_msg).
    lo_log->add_message( ).
  ENDIF.

  "Es gibt mehrere wege um Matids zu convertieren hier ein Beispiel.
  DATA(ui_stock_helper) = NEW /scwm/cl_ui_stock_fields( ).

  lo_packing->create_hu( EXPORTING iv_pmat      = ui_stock_helper->get_matid_by_no( iv_matnr = ppmat )               " Material GUID16 with Conversion Exit
                                   i_location   = p_lgpla
                         RECEIVING es_huhdr     = huhdr                  " Internal Structure for Processing the HU Header
                         EXCEPTIONS error        = 1
                                    OTHERS       = 2 ).
  IF sy-subrc <> 0.
    "Fehler! HU konnte nicht erstellt werden
    MESSAGE e000(zsbt_ewm_muster) INTO lv_msg.
    lo_log->add_message( ).
  ELSE.
    "HU erstellt HUIDENT: &1
    MESSAGE s013(zsbt_ewm_muster)  WITH huhdr-huident INTO lv_msg.
    lo_log->add_message( ).
  ENDIF.

  "An dieser Stelle existiert die HU nur innerhalb unserer Laufzeit, ist aber noch nicht auf Datenbankebene gespeichert
  "sieht man daran wir können hier auf die HU Zugreiffen werden diese hier aber noch nicht im Lagerverwaltungmonitor /scwm/mon finden
  BREAK-POINT.

  IF p_save = abap_true.

    lo_packing->save( EXCEPTIONS OTHERS = 99 ).
    IF sy-subrc = 0.
      "HU wurde erfolgreich gespeichert
      MESSAGE s004(zsbt_ewm_muster) WITH huhdr-huident huhdr-lgpla INTO lv_msg.
      lo_log->add_message( ).

    ENDIF.

    CALL FUNCTION '/SCWM/HUHEADER_READ'
      EXPORTING
        iv_huident  = huhdr-huident                 " Handling Unit Identifikation
      IMPORTING
        es_huheader = huhdr_result                " interne Struktur zur Bearbeitung des HU-Kopfes
      EXCEPTIONS
        OTHERS      = 99.
    IF sy-subrc = 0.
      "HU existiert auf Datenbankebene
      MESSAGE s005(zsbt_ewm_muster) INTO lv_msg.
      lo_log->add_message( ).
    ENDIF.

  ELSE.
    "HU konnte nicht gespeichert werden
    MESSAGE e003(zsbt_ewm_muster) INTO lv_msg.
    lo_log->add_message( ).
    /scwm/cl_tm=>cleanup( iv_lgnum = p_lgnum ).
  ENDIF.

  "Logging Speichern(->kann dann in der SLG1 ausgelesen werden) und Anzeigen
  lo_log->save_applog( EXPORTING is_log = VALUE #(  )
                       IMPORTING ev_loghandle = DATA(loghandle) ).

  "Display Profil um Log als Popup auszugeben
  CALL FUNCTION 'BAL_DSP_PROFILE_POPUP_GET'
    IMPORTING
      e_s_display_profile = ls_display_profile.

  lo_log->display_log( EXPORTING iv_loghandle       =     loghandle
                                 is_display_profile =     ls_display_profile ).
