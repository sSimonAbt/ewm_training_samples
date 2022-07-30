*&---------------------------------------------------------------------*
*& Report zsbt_move_hu
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zsbt_move_hu.

DATA: lo_packing         TYPE REF TO /scwm/cl_wm_packing,
      lo_log             TYPE REF TO /scwm/cl_log,
      ls_display_profile TYPE bal_s_prof,
      ls_huhdr           TYPE /scwm/s_huhdr_int.

PARAMETERS: p_lgnum TYPE /scwm/lgnum,
            p_hu    TYPE /scwm/huident,
            p_lgpla TYPE /scwm/de_lgpla DEFAULT '0020-01-02-C',
            pprocty TYPE /scwm/de_procty DEFAULT '9999'.

/scwm/cl_tm=>set_lgnum( EXPORTING iv_lgnum = p_lgnum ).

"Erstellen des Log Objektes
lo_log = NEW /scwm/cl_log( iv_balobj       = 'ZSBT'
                           iv_balsubobj    = 'ZSBT_MUSTER_SCHULUNG' ).

/scwm/cl_wm_packing=>get_instance( IMPORTING eo_instance = lo_packing ).

lo_packing->init( EXPORTING iv_lgnum = p_lgnum
                  EXCEPTIONS OTHERS = 99 ).
IF sy-subrc <> 0.
  "Fehler beim instanziieren der Packing Klasse
  MESSAGE e001(zsbt_ewm_muster) INTO DATA(lv_msg).
  lo_log->add_message( ).
ENDIF.

"Wir brauchen die GUID der HU, daher Header auslesene zur HU
CALL FUNCTION '/SCWM/HUHEADER_READ'
  EXPORTING
    iv_appl     = wmegc_huappl_wme
    iv_huident  = p_hu
    iv_nobuff   = abap_false
  IMPORTING
    es_huheader = ls_huhdr
  EXCEPTIONS
    OTHERS      = 99.
IF sy-subrc <> 0.
  "Fehler! HU konnte nicht gefunden werden
  MESSAGE e006(zsbt_ewm_muster) INTO lv_msg.
  lo_log->add_message( ).
ENDIF.

lo_packing->/scwm/if_pack_bas~move_hu( EXPORTING iv_hu  = ls_huhdr-guid_hu
                                                 iv_bin = p_lgpla
                                       EXCEPTIONS OTHERS = 99 ).

IF sy-subrc <> 0.
  "Fehler HU konnte nicht bewegt werden!
  MESSAGE e007(zsbt_ewm_muster) INTO lv_msg.
  lo_log->add_message( ).
ENDIF.

lo_packing->/scwm/if_pack~save( EXCEPTIONS OTHERS = 99 ).
IF sy-subrc <> 0.
  "Änderungen konnten nicht gespeichert werden!
  MESSAGE e008(zsbt_ewm_muster) INTO lv_msg.
  lo_log->add_message( ).
  ROLLBACK WORK.
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
