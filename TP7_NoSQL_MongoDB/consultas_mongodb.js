/**
 * ============================================================================
 * TRABAJO PRÁCTICO · UNIDAD 7: NoSQL Y NUEVAS FORMAS DE ALMACENAMIENTO
 * Caso: Food Store - Base Documental de Pedidos
 * Integrantes: Tiziano Valentini y Juan Martin Garcia
 * Repositorio: Trabajos-Practicos-BD-Valentini-Garcia
 * Archivo: TP8_NoSQL_MongoDB/consultas_mongodb.js
 * ============================================================================
 * 
 * Script completo y ejecutable en mongosh.
 * Realiza:
 *  1. Selección/creación de la base de datos 'food_store_nosql'.
 *  2. Creación e inicialización limpia de la colección 'pedidos'.
 *  3. Inserción con insertMany() de 6 pedidos reales extraídos del esquema
 *     relacional de PostgreSQL (conservando IDs, clientes, líneas históricas y subtotales).
 *  4. Ejecución de las 4 consultas requeridas en la Consigna 4:
 *     - a) Mostrar todos los pedidos (identificador y estado).
 *     - b) Filtrar pedidos por estado existente ('ENTREGADO').
 *     - c) Buscar pedidos que contengan un producto determinado (id_producto: 3, Coca 1.5L).
 *     - d) Buscar pedidos con total_pedido superior al umbral justificado ($15.000,00).
 * ============================================================================
 */

// 1. Conexión y selección de la base de datos
db = db.getSiblingDB('food_store_nosql');

print("\n============================================================================");
print(" >>> SELECCIONANDO BASE DE DATOS: " + db.getName());
print("============================================================================\n");

// Limpieza previa para garantizar idempotencia en la ejecución
db.pedidos.drop();

// 2. Inserción de los pedidos reales migrados desde PostgreSQL
// Se conservan los IDs originales, timestamps, estados, snapshots de cliente,
// arreglos de líneas con categoría y precio unitario histórico pactado, y el total.
const pedidosMigrados = [
  {
    id_pedido: 1,
    fecha_hora: ISODate("2026-09-21T22:22:22.225Z"),
    forma_pago: "EFECTIVO",
    estado: "ENTREGADO",
    eliminado: false,
    cliente: {
      id_cliente: 1,
      nombre: "Ana Gómez",
      email: "ana.gomez@example.com"
    },
    lineas: [
      {
        id_producto: 1,
        nombre_producto: "Muzzarella",
        categoria: "Pizzas",
        cantidad: 2,
        precio_unitario: 1050.00,
        subtotal: 2100.00
      },
      {
        id_producto: 3,
        nombre_producto: "Coca 1.5L",
        categoria: "Bebidas",
        cantidad: 1,
        precio_unitario: 800.00,
        subtotal: 800.00
      },
      {
        id_producto: 6,
        nombre_producto: "Producto FoodStore 1",
        categoria: "Almacén",
        cantidad: 2,
        precio_unitario: 3113.43,
        subtotal: 6226.86
      },
      {
        id_producto: 7,
        nombre_producto: "Producto FoodStore 2",
        categoria: "Postres",
        cantidad: 2,
        precio_unitario: 4338.74,
        subtotal: 8677.48
      }
    ],
    total_pedido: 17804.34
  },
  {
    id_pedido: 2,
    fecha_hora: ISODate("2026-09-26T22:22:22.225Z"),
    forma_pago: "TARJETA",
    estado: "ENTREGADO",
    eliminado: false,
    cliente: {
      id_cliente: 2,
      nombre: "Luis Paz",
      email: "luis.paz@example.com"
    },
    lineas: [
      {
        id_producto: 2,
        nombre_producto: "Napolitana",
        categoria: "Pizzas",
        cantidad: 1,
        precio_unitario: 1500.00,
        subtotal: 1500.00
      },
      {
        id_producto: 8,
        nombre_producto: "Producto FoodStore 3",
        categoria: "Postres",
        cantidad: 2,
        precio_unitario: 2245.58,
        subtotal: 4491.16
      },
      {
        id_producto: 9,
        nombre_producto: "Producto FoodStore 4",
        categoria: "Bebidas",
        cantidad: 3,
        precio_unitario: 3890.33,
        subtotal: 11670.99
      }
    ],
    total_pedido: 17662.15
  },
  {
    id_pedido: 3,
    fecha_hora: ISODate("2026-09-30T22:22:22.225Z"),
    forma_pago: "TRANSFERENCIA",
    estado: "EN_PREPARACION",
    eliminado: false,
    cliente: {
      id_cliente: 3,
      nombre: "Marta Ruiz",
      email: "marta.ruiz@example.com"
    },
    lineas: [
      {
        id_producto: 2,
        nombre_producto: "Napolitana",
        categoria: "Pizzas",
        cantidad: 2,
        precio_unitario: 1500.00,
        subtotal: 3000.00
      },
      {
        id_producto: 3,
        nombre_producto: "Coca 1.5L",
        categoria: "Bebidas",
        cantidad: 4,
        precio_unitario: 800.00,
        subtotal: 3200.00
      },
      {
        id_producto: 10,
        nombre_producto: "Producto FoodStore 5",
        categoria: "Limpieza",
        cantidad: 2,
        precio_unitario: 1926.54,
        subtotal: 3853.08
      },
      {
        id_producto: 11,
        nombre_producto: "Producto FoodStore 6",
        categoria: "Carnicería y Granja",
        cantidad: 2,
        precio_unitario: 1243.15,
        subtotal: 2486.30
      }
    ],
    total_pedido: 12539.38
  },
  {
    id_pedido: 4,
    fecha_hora: ISODate("2025-01-05T17:38:06.391Z"),
    forma_pago: "TARJETA",
    estado: "ENTREGADO",
    eliminado: false,
    cliente: {
      id_cliente: 7653,
      nombre: "Cliente 7650",
      email: "usuario_7650@foodstore.com"
    },
    lineas: [
      {
        id_producto: 12,
        nombre_producto: "Producto FoodStore 7",
        categoria: "Snacks",
        cantidad: 1,
        precio_unitario: 811.44,
        subtotal: 811.44
      },
      {
        id_producto: 13,
        nombre_producto: "Producto FoodStore 8",
        categoria: "Congelados",
        cantidad: 2,
        precio_unitario: 1182.13,
        subtotal: 2364.26
      }
    ],
    total_pedido: 3175.70
  },
  {
    id_pedido: 5,
    fecha_hora: ISODate("2026-08-29T11:38:48.485Z"),
    forma_pago: "BILLETERA_DIGITAL",
    estado: "ENTREGADO",
    eliminado: false,
    cliente: {
      id_cliente: 19193,
      nombre: "Cliente 19190",
      email: "usuario_19190@foodstore.com"
    },
    lineas: [
      {
        id_producto: 14,
        nombre_producto: "Producto FoodStore 9",
        categoria: "Almacén",
        cantidad: 4,
        precio_unitario: 3095.70,
        subtotal: 12382.80
      },
      {
        id_producto: 15,
        nombre_producto: "Producto FoodStore 10",
        categoria: "Panificados",
        cantidad: 4,
        precio_unitario: 3180.31,
        subtotal: 12721.24
      }
    ],
    total_pedido: 25104.04
  },
  {
    id_pedido: 6,
    fecha_hora: ISODate("2025-12-02T12:38:04.717Z"),
    forma_pago: "TRANSFERENCIA",
    estado: "PENDIENTE",
    eliminado: false,
    cliente: {
      id_cliente: 14472,
      nombre: "Cliente 14469",
      email: "usuario_14469@foodstore.com"
    },
    lineas: [
      {
        id_producto: 16,
        nombre_producto: "Producto FoodStore 11",
        categoria: "Limpieza",
        cantidad: 4,
        precio_unitario: 3284.84,
        subtotal: 13139.36
      },
      {
        id_producto: 17,
        nombre_producto: "Producto FoodStore 12",
        categoria: "Congelados",
        cantidad: 4,
        precio_unitario: 2790.12,
        subtotal: 11160.48
      }
    ],
    total_pedido: 24299.84
  }
];

const resultadoInsercion = db.pedidos.insertMany(pedidosMigrados);
print(" >>> EVIDENCIA DE INSERCIÓN (insertMany):");
printjson(resultadoInsercion);
print(` >>> Total documentos insertados: ${Object.keys(resultadoInsercion.insertedIds).length}\n`);

// Creación de índices para optimizar los patrones de acceso frecuentes
db.pedidos.createIndex({ id_pedido: 1 }, { unique: true, name: "idx_pedidos_id_pedido_uq" });
db.pedidos.createIndex({ estado: 1 }, { name: "idx_pedidos_estado" });
db.pedidos.createIndex({ "lineas.id_producto": 1 }, { name: "idx_pedidos_lineas_producto" });
db.pedidos.createIndex({ total_pedido: -1 }, { name: "idx_pedidos_total" });

print("============================================================================");
print(" CONSIGNA 4 (a): Mostrar todos los pedidos, incluyendo identificador y estado");
print("============================================================================");
const consultaA = db.pedidos.find(
  {},
  { id_pedido: 1, estado: 1, forma_pago: 1, total_pedido: 1, _id: 0 }
).sort({ id_pedido: 1 }).toArray();

printjson(consultaA);
print(`Total recuperados consulta (a): ${consultaA.length}\n`);

print("============================================================================");
print(" CONSIGNA 4 (b): Filtrar pedidos por un estado existente ('ENTREGADO')");
print("============================================================================");
const consultaB = db.pedidos.find(
  { estado: "ENTREGADO" },
  { id_pedido: 1, fecha_hora: 1, forma_pago: 1, estado: 1, "cliente.nombre": 1, total_pedido: 1, _id: 0 }
).sort({ id_pedido: 1 }).toArray();

printjson(consultaB);
print(`Total recuperados consulta (b): ${consultaB.length}\n`);

print("============================================================================");
print(" CONSIGNA 4 (c): Buscar pedidos que contengan un producto determinado en lineas");
print(" Criterio: id_producto = 3 (Coca 1.5L)");
print("============================================================================");
const consultaC = db.pedidos.find(
  { "lineas.id_producto": 3 },
  { 
    id_pedido: 1, 
    fecha_hora: 1, 
    estado: 1, 
    "cliente.nombre": 1,
    lineas: { $elemMatch: { id_producto: 3 } }, 
    total_pedido: 1, 
    _id: 0 
  }
).sort({ id_pedido: 1 }).toArray();

printjson(consultaC);
print(`Total recuperados consulta (c): ${consultaC.length}\n`);

print("============================================================================");
print(" CONSIGNA 4 (d): Buscar pedidos cuyo total sea superior a un importe elegido");
print(" Criterio: total_pedido > 15000.00 (Pedidos de Alto Valor)");
print("============================================================================");
const consultaD = db.pedidos.find(
  { total_pedido: { $gt: 15000.00 } },
  { id_pedido: 1, estado: 1, "cliente.nombre": 1, total_pedido: 1, _id: 0 }
).sort({ total_pedido: -1 }).toArray();

printjson(consultaD);
print(`Total recuperados consulta (d): ${consultaD.length}\n`);
