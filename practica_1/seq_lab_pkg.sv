`timescale 1ns/1ps
package seq_lab_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum {WRITE, READ} kind_e;

  // ---------------- Item ----------------
  class bus_item extends uvm_sequence_item;
    rand kind_e    kind;
    rand bit [7:0] addr;
    rand bit [7:0] data;
    string         tag;     // etiqueta para seguir el item en el log
    constraint c_addr { addr < 16; }
    `uvm_object_utils_begin(bus_item)
      `uvm_field_enum(kind_e, kind, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_string(tag, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "bus_item"); super.new(name); endfunction
    function string convert2string();
      return $sformatf("%-4s %-5s addr=0x%02h data=0x%02h", tag, kind.name(), addr, data);
    endfunction
  endclass

  typedef uvm_sequencer #(bus_item) bus_sequencer;

  // ---------------- Driver ----------------
  class bus_driver extends uvm_driver #(bus_item);
    `uvm_component_utils(bus_driver)
    bit [7:0] mem [bit [7:0]];   // modelo de memoria
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    // Conduce un item: 10 ns; en lecturas escribe el dato leído en el propio item
    virtual task drive(bus_item it);
      #10ns;
      if (it.kind == WRITE) mem[it.addr] = it.data;
      else                  it.data = mem.exists(it.addr) ? mem[it.addr] : 8'hFF;
    endtask

    task run_phase(uvm_phase phase);
      forever begin
        // TODO 1: pide el siguiente item en req
        seq_item_port.get_next_item(req);
        `uvm_info("DRV", {"recibo  ", req.convert2string()}, UVM_LOW)
        drive(req);
        `uvm_info("DRV", {"termino ", req.convert2string()}, UVM_LOW)
        // TODO 2: indica que has terminado con el item
        seq_item_port.item_done();
      end
    endtask
  endclass

  // ---------------- Agente y env ----------------
  class bus_agent extends uvm_agent;
    `uvm_component_utils(bus_agent)
    bus_sequencer sqr;
    bus_driver    drv;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      sqr = bus_sequencer::type_id::create("sqr", this);
      drv = bus_driver::type_id::create("drv", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  class bus_env extends uvm_env;
    `uvm_component_utils(bus_env)
    bus_agent agt;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      agt = bus_agent::type_id::create("agt", this);
    endfunction
  endclass

  // ---------------- Secuencia básica con trazas ----------------
  class basic_seq extends uvm_sequence #(bus_item);
    `uvm_object_utils(basic_seq)
    int unsigned n      = 3;
    string       prefix = "S";
    function new(string name = "basic_seq"); super.new(name); endfunction

    task body();
      for (int i = 0; i < n; i++) begin
        req = bus_item::type_id::create("req");
        req.tag = $sformatf("%s%0d", prefix, i);
        `uvm_info("SEQ", {req.tag, ": llamo a start_item"}, UVM_LOW)
        // TODO 3: pide turno
        start_item(req);
        `uvm_info("SEQ", {req.tag, ": start_item devuelve; aleatorizo"}, UVM_LOW)
        // TODO 4: aleatoriza como escritura
        if (!req.randomize() with { kind == WRITE; }) begin
          `uvm_error("SEQ", {req.tag, ": fallo aleatorizacion"})
        end
        `uvm_info("SEQ", {req.tag, ": llamo a finish_item"}, UVM_LOW)
        // TODO 5: entrega el item
        finish_item(req);
        `uvm_info("SEQ", {req.tag, ": finish_item devuelve"}, UVM_LOW)
      end
    endtask
  endclass

  // ---------------- Test base ----------------
  class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    bus_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      env = bus_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      basic_seq seq = basic_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  // Aquí irán las clases de las prácticas

  // ---------------- Práctica 2A: dato en el propio item ----------------
  class wr_rd_seq extends uvm_sequence #(bus_item);
    `uvm_object_utils(wr_rd_seq)
    function new(string name = "wr_rd_seq"); super.new(name); endfunction

    task body();
      bus_item wr, rd;
      wr = bus_item::type_id::create("wr");
      start_item(wr);
      if (!wr.randomize() with { kind == WRITE; addr == 3; data == 8'hA5; }) `uvm_error("RAND", "")
      wr.tag = "WR";
      finish_item(wr);

      rd = bus_item::type_id::create("rd");
      start_item(rd);
      if (!rd.randomize() with { kind == READ; addr == 3; }) `uvm_error("RAND", "")
      rd.tag = "RD";
      finish_item(rd);

      // TODO 6: comprueba que rd.data vale 0xA5; uvm_error si no
      if (rd.data != 8'hA5)
        `uvm_error("CHK", $sformatf("esperaba 0xA5, lei 0x%02h", rd.data))
      else
        `uvm_info("CHK", $sformatf("lei 0x%02h, correcto", rd.data), UVM_LOW)
    endtask
  endclass

  class wr_rd_test extends base_test;
    `uvm_component_utils(wr_rd_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      wr_rd_seq seq = wr_rd_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  // ---------------- Práctica 2B: respuesta separada ----------------
  class rsp_driver extends bus_driver;
    `uvm_component_utils(rsp_driver)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      forever begin
        bus_item item_copy;
        seq_item_port.get_next_item(req);
        // Conduce una copia: la secuencia no ve cambios en su item original
        $cast(item_copy, req.clone());
        drive(item_copy);
        rsp = bus_item::type_id::create("rsp");
        rsp.tag  = req.tag;
        rsp.kind = req.kind;
        rsp.addr = req.addr;
        rsp.data = item_copy.data;
        `uvm_info("DRV", {"respondo ", rsp.convert2string()}, UVM_LOW)
        // TODO 7: asocia rsp a req y entrégala junto con item_done
        rsp.set_id_info(req);
        seq_item_port.item_done(rsp);
      end
    endtask
  endclass

  class rsp_seq extends uvm_sequence #(bus_item);
    `uvm_object_utils(rsp_seq)
    int unsigned n_writes           = 1;
    bit          recoger_escrituras = 1;   // Experimento E: 0 = no recoger las respuestas de las escrituras
    function new(string name = "rsp_seq"); super.new(name); endfunction
    task body();
      bit [7:0] data_antes;
      for (int i = 0; i < n_writes; i++) begin
        req = bus_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { kind == WRITE; addr == i; data == 8'h10 + i; }) `uvm_error("RAND", "")
        req.tag = $sformatf("W%0d", i);
        finish_item(req);
        // TODO 8: recoge la respuesta de esta escritura
        if (recoger_escrituras) begin
          get_response(rsp);
          `uvm_info("SEQ", {"recibo respuesta ", rsp.convert2string()}, UVM_LOW)
        end
      end
      req = bus_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { kind == READ; addr == 0; }) `uvm_error("RAND", "")
      req.tag = "R0";
      data_antes = req.data;
      finish_item(req);
      // TODO 9: recoge la respuesta de la lectura e imprime el dato
      get_response(rsp);
      `uvm_info("SEQ", {"respuesta de la lectura: ", rsp.convert2string()}, UVM_LOW)
      if (rsp.data != 8'h10)
        `uvm_error("CHK", $sformatf("R0: esperaba 0x10, lei 0x%02h", rsp.data))
      else
        `uvm_info("CHK", $sformatf("R0: lei 0x%02h, correcto", rsp.data), UVM_LOW)
      if (req.data != data_antes)
        `uvm_error("CHK", "req.data cambio: el driver toco el item original")
      else
        `uvm_info("CHK", $sformatf("req.data no cambio (sigue en 0x%02h)", req.data), UVM_LOW)
    endtask
  endclass

  class rsp_test extends base_test;
    `uvm_component_utils(rsp_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      // Antes de crear el env: la fábrica creará rsp_driver donde se pida bus_driver
      set_type_override_by_type(bus_driver::get_type(), rsp_driver::get_type());
      super.build_phase(phase);
    endfunction
    task run_phase(uvm_phase phase);
      rsp_seq seq = rsp_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  // Experimento E: 12 escrituras sin recoger sus respuestas
  class rsp_e_test extends rsp_test;
    `uvm_component_utils(rsp_e_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      rsp_seq seq = rsp_seq::type_id::create("seq");
      seq.n_writes           = 12;
      seq.recoger_escrituras = 0;
      phase.raise_objection(this);
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  // Experimento F: respuestas con manejador, sin cola
  class rsp_handler_seq extends rsp_seq;
    `uvm_object_utils(rsp_handler_seq)
    int unsigned n_rsp = 0;   // cuántas respuestas han llegado
    function new(string name = "rsp_handler_seq");
      super.new(name);
      use_response_handler(1);   // UVM llamará a response_handler con cada respuesta
    endfunction

    // UVM la llama automáticamente por cada respuesta: no hay cola que se llene
    virtual function void response_handler(uvm_sequence_item response);
      bus_item r;
      $cast(r, response);
      n_rsp++;
      `uvm_info("HDL", $sformatf("respuesta #%0d: %s", n_rsp, r.convert2string()), UVM_LOW)
      if (r.tag == "R0") begin
        if (r.data != 8'h10)
          `uvm_error("CHK", $sformatf("R0: esperaba 0x10, lei 0x%02h", r.data))
        else
          `uvm_info("CHK", "R0: lei 0x10, correcto (y la respuesta si es de R0)", UVM_LOW)
      end
    endfunction

    task body();
      for (int i = 0; i < n_writes; i++) begin
        req = bus_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { kind == WRITE; addr == i; data == 8'h10 + i; }) `uvm_error("RAND", "")
        req.tag = $sformatf("W%0d", i);
        finish_item(req);
        // Sin TODO 8: la respuesta la procesa response_handler
      end
      req = bus_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { kind == READ; addr == 0; }) `uvm_error("RAND", "")
      req.tag = "R0";
      finish_item(req);
      // Sin TODO 9: la respuesta de R0 también llega a response_handler
    endtask
  endclass

  class rsp_f_test extends rsp_test;
    `uvm_component_utils(rsp_f_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      rsp_handler_seq seq = rsp_handler_seq::type_id::create("seq");
      seq.n_writes = 12;
      phase.raise_objection(this);
      seq.start(env.agt.sqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage