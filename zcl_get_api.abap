CLASS zcl_get_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.
*EOD data structure
    TYPES:
      BEGIN OF ty_results,
        c  TYPE p LENGTH 16 DECIMALS 4,
        h  TYPE p LENGTH 16 DECIMALS 4,
        l  TYPE p LENGTH 16 DECIMALS 4,
        n  TYPE i,
        o  TYPE p LENGTH 16 DECIMALS 4,
        t  TYPE timestamp,
        v  TYPE i,
        vw TYPE f,
        tk TYPE c LENGTH 4,
      END OF ty_results,
      my_result TYPE STANDARD TABLE OF ty_results WITH DEFAULT KEY.

    METHODS:
      create_client
        IMPORTING url           TYPE string
        RETURNING VALUE(result) TYPE REF TO if_web_http_client
        RAISING   cx_static_check,

      read_eod
        IMPORTING lv_ticker         TYPE string
                  lv_data           TYPE d
                  lv_apikey         TYPE string
        RETURNING VALUE(lt_results) TYPE my_result
        RAISING   cx_static_check.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS:
      base_url     TYPE string VALUE 'https://api.polygon.io/v2/aggs/ticker/',
      content_type TYPE string VALUE 'Content-type',
      json_content TYPE string VALUE 'application/json; charset=UTF-8',
      apikey       TYPE string VALUE 'PUT YOUR API KEY HERE'.
ENDCLASS.



CLASS zcl_get_api IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    TRY.
        DATA(aapl) = read_eod( EXPORTING lv_ticker ='AAPL' lv_data = '20230801' lv_apikey = apikey ).
      CATCH cx_root INTO DATA(exc).
        out->write( exc->get_text(  ) ).
    ENDTRY.

    out->write( aapl ).
  ENDMETHOD.

  METHOD create_client.
    DATA(dest) = cl_http_destination_provider=>create_by_url( url ).
    result = cl_web_http_client_manager=>create_by_http_destination( dest ).
  ENDMETHOD.

  METHOD read_eod.
*GET JSON string into response variable
    DATA(url) = |{ base_url }| &
                |{ lv_ticker }| &
                |/range/1/day/2021-01-09/| &
                |{ lv_data DATE = ISO  }| &
                |?adjusted=true&sort=asc&limit=50000&apiKey=| &
                |{ lv_apikey }|.

    DATA(client) = create_client( url ).
    DATA(response) = client->execute( if_web_http_client=>get )->get_text(  ).
    client->close(  ).

* Parse JSON string into internal table
    DATA: lv_val    TYPE string,
          lr_data   TYPE REF TO data,
          ls_result TYPE ty_results,
          lt_result TYPE STANDARD TABLE OF ty_results WITH EMPTY KEY.

    FIELD-SYMBOLS : <lfs_table> TYPE ANY TABLE.

    /ui2/cl_json=>deserialize(
      EXPORTING
        json         = response
        pretty_name  = /ui2/cl_json=>pretty_mode-user
        assoc_arrays = abap_true
      CHANGING
        data         = lr_data ).


    ASSIGN lr_data->* TO FIELD-SYMBOL(<fs_data>).
    ASSIGN COMPONENT 'RESULTS' OF STRUCTURE <fs_data> TO FIELD-SYMBOL(<fs_results>).
    ASSIGN <fs_results>->* TO <lfs_table>.
    DATA(lv_size) = lines( <lfs_table> ).

    LOOP AT <lfs_table> ASSIGNING FIELD-SYMBOL(<lfs_row>).

      DO 8 TIMES. "Number of fields

        CASE sy-index.
          WHEN 1. DATA(lv_fname) = 'C'.
          WHEN 2. lv_fname = 'H'.
          WHEN 3. lv_fname = 'L'.
          WHEN 4. lv_fname = 'N'.
          WHEN 5. lv_fname = 'O'.
          WHEN 6. lv_fname = 'T'.
          WHEN 7. lv_fname = 'V'.
          WHEN 8. lv_fname = 'VW'.

        ENDCASE.

        ASSIGN COMPONENT sy-index OF STRUCTURE ls_result TO FIELD-SYMBOL(<result_field>).
        ASSIGN <lfs_row>->* TO FIELD-SYMBOL(<lfs_row_val>).
        ASSIGN COMPONENT lv_fname OF STRUCTURE <lfs_row_val> TO FIELD-SYMBOL(<lfs_ref_value>).
        IF <lfs_ref_value> IS ASSIGNED AND <result_field> IS ASSIGNED.
          ASSIGN <lfs_ref_value>->* TO FIELD-SYMBOL(<lfs_actual_value>).
          IF <lfs_actual_value> IS ASSIGNED.
            <result_field> = <lfs_actual_value>.
          ENDIF.
        ENDIF.
      ENDDO.
      ls_result-tk = lv_ticker.
      APPEND ls_result TO lt_result.
    ENDLOOP.

    lt_results = lt_result.
  ENDMETHOD.

ENDCLASS.
