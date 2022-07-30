*&---------------------------------------------------------------------*
*& Report zsbt_repack_product
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zsbt_repack_product.

DATA: lt_hu_items        TYPE /scwm/tt_huitm_int,
      lo_log             TYPE REF TO /scwm/cl_log,
      ls_display_profile TYPE bal_s_prof,
      lo_packing         TYPE REF TO  /scwm/cl_wm_packing.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE input.

PARAMETERS: p_lgnum TYPE /scwm/lgnum DEFAULT 'WU01',
            p_shu   TYPE /scwm/de_huident DEFAULT 8000158, "source hu
            p_deshu TYPE /scwm/de_huident DEFAULT 8000261, "target hu
            p_quant TYPE /scwm/de_quantity DEFAULT 1.      "what quantity

SELECTION-SCREEN END OF BLOCK b01.

START-OF-SELECTION.
  lo_log = NEW /scwm/cl_log( iv_balobj       = 'ZSBT'
                             iv_balsubobj    = 'ZSBT_MUSTER_SCHULUNG' ).

  /scwm/cl_tm=>set_lgnum( iv_lgnum = p_lgnum ).
  /scwm/cl_wm_packing=>get_instance( IMPORTING eo_instance = lo_packing ).


  lo_packing->init( EXPORTING iv_lgnum = p_lgnum EXCEPTIONS OTHERS = 99 ).
  IF sy-subrc <> 0.
    "Fehler beim instanziieren der Packing Klasse
    MESSAGE e001(zsbt_ewm_muster) INTO DATA(lv_msg).
    lo_log->add_message( ).
  ENDIF.

  lo_packing->/scwm/if_pack_bas~hu_gt_fill( EXPORTING it_huident   = VALUE /scwm/tt_huident( ( huident = p_shu )
                                                                                             ( huident = p_deshu ) )
                                                IMPORTING et_huitm     = lt_hu_items
                                                EXCEPTIONS OTHERS      = 99 ).
  IF sy-subrc <> 0.
    "Fehler HU Daten konnten nicht gefüllt werden
    MESSAGE e009(zsbt_ewm_muster) INTO lv_msg.
    lo_log->add_message( ).
  ENDIF.


  TRY.
      DATA(source_hu_item) = lt_hu_items[ 1 ].
      DATA(target_hu_item) = lt_hu_items[ 2 ].
    CATCH cx_sy_itab_line_not_found.
      "Fehler! HU oder HU Item konnte nicht gefunden werden
      MESSAGE e010(zsbt_ewm_muster) INTO lv_msg.
      lo_log->add_message( ).
  ENDTRY.

  lo_packing->repack_stock( EXPORTING iv_source_hu  = source_hu_item-guid_parent "from an item perspective, the parent is our HU (tree view)
                                          iv_dest_hu    = target_hu_item-guid_parent
                                          iv_stock_guid = source_hu_item-guid_stock
                                          is_quantity = VALUE #( unit = source_hu_item-meins "ST, PC, KG etc.
                                                                 quan = p_quant )
                              EXCEPTIONS OTHERS = 99 ).
  IF sy-subrc <> 0.
    "Fehler Produkt konnte nicht umgepackt werden
    MESSAGE e011(zsbt_ewm_muster) INTO lv_msg.
    lo_log->add_message( ).

  ELSE.
    lo_packing->save( EXCEPTIONS OTHERS = 99 ).
    IF sy-subrc <> 0.
      "Änderungen konnten nicht gespeichert werden!
      MESSAGE e008(zsbt_ewm_muster) INTO lv_msg.
      lo_log->add_message( ).
      /scwm/cl_tm=>cleanup( iv_lgnum = p_lgnum ).
      ROLLBACK WORK.
    ELSE.
      /scwm/cl_tm=>cleanup( iv_lgnum = p_lgnum ).
      "Es wurde erfolgreich ein Produkt von einer HU in einer andere gepackt
      MESSAGE s012(zsbt_ewm_muster) INTO lv_msg.
      lo_log->add_message( ).
    ENDIF.

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
