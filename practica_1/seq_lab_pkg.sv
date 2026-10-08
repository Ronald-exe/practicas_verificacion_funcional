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
        `uvm_info("SEQ", {req.tag, ": start_item devuelve; aleatorizo"}, UVM_LOW)
        // TODO 4: aleatoriza como escritura
        `uvm_info("SEQ", {req.tag, ": llamo a finish_item"}, UVM_LOW)
        // TODO 5: entrega el item
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
endpackage
