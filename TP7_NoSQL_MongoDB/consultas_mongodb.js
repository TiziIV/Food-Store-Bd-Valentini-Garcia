/**
 * ============================================================================
 * TRABAJO PRÁCTICO · UNIDAD 7: NoSQL Y NUEVAS FORMAS DE ALMACENAMIENTO
 * Caso: Food Store - Base Documental de Pedidos
 * Integrantes: Tiziano Valentini y Juan Martin Garcia
 * Repositorio: Food-Store-Bd-Valentini-Garcia (rama: trabajos-practicos-nosql)
 * Archivo: TP7_NoSQL_MongoDB/consultas_mongodb.js
 * ============================================================================
 * 
 * Script completo y ejecutable en mongosh.
 * Realiza:
 *  1. Selección/creación de la base de datos 'food_store_nosql'.
 *  2. Creación explícita de la colección 'pedidos' con validador formal
 *     $jsonSchema (exigiendo Decimal128 para importes, enum de estados y
 *     formas de pago, minItems: 1 en lineas y campos obligatorios).
 *  3. Inserción con insertMany() de 6 pedidos reales extraídos del esquema
 *     relacional de PostgreSQL, usando NumberDecimal("...") (Decimal128)
 *     para todos los campos monetarios (precio_unitario, subtotal, total_pedido).
 *  4. Prueba de validación negativa (intento de inserción con importes en
 *     double), capturando el rechazo real 'Document failed validation'.
 *  5. Ejecución de las 4 consultas requeridas en la Consigna 4:
 *     - a) Mostrar todos los pedidos (identificador, estado, forma_pago y total).
 *     - b) Filtrar pedidos por estado existente ('ENTREGADO').
 *     - c) Buscar pedidos que contengan un producto determinado (id_producto: 3, Coca 1.5L).
 *     - d) Buscar pedidos con total_pedido superior al umbral justificado (NumberDecimal("15000.00")).
 *  6. Pruebas de laboratorio para el contraste crítico de IA (Consigna 7):
 *     - Precisión aritmética IEEE 754 double vs BSON Decimal128.
 *     - Plan de ejecución explain("executionStats") en lectura de agregado.
 *     - Pipeline de agregación ($match + $unwind + $group + $sort) con Decimal128.
 * ============================================================================
 */

// 1. Conexión y selección de la base de datos
db = db.getSiblingDB('food_store_nosql');

print("\n============================================================================");
print(" >>> SELECCIONANDO BASE DE DATOS: " + db.getName());
print("============================================================================\n");

// Limpieza previa para garantizar idempotencia en la ejecución
db.pedidos.drop();

// 2. Creación de la colección 'pedidos' con validador formal $jsonSchema
const resultadoCreacionColeccion = db.createCollection("pedidos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "Validador de esquema para la coleccion pedidos de Food Store",
      required: [
        "id_pedido",
        "fecha_hora",
        "forma_pago",
        "estado",
        "eliminado",
        "cliente",
        "lineas",
        "total_pedido"
      ],
      properties: {
        id_pedido: {
          bsonType: ["int", "long"],
          minimum: 1,
          description: "Identificador entero positivo del pedido migrado desde PostgreSQL (obligatorio)."
        },
        fecha_hora: {
          bsonType: "date",
          description: "Fecha y hora de emision del pedido en formato ISODate (obligatorio)."
        },
        forma_pago: {
          enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA", "BILLETERA_DIGITAL"],
          description: "Medio de pago permitido segun el dominio de Food Store (obligatorio)."
        },
        estado: {
          enum: ["ENTREGADO", "EN_PREPARACION", "PENDIENTE", "CANCELADO"],
          description: "Estado valido del ciclo de vida del pedido (obligatorio)."
        },
        eliminado: {
          bsonType: "bool",
          description: "Bandera booleana de borrado logico / soft delete (obligatorio)."
        },
        cliente: {
          bsonType: "object",
          required: ["id_cliente", "nombre", "email"],
          properties: {
            id_cliente: {
              bsonType: ["int", "long"],
              minimum: 1,
              description: "Identificador del cliente en PostgreSQL."
            },
            nombre: {
              bsonType: "string",
              minLength: 1,
              description: "Nombre completo del cliente al momento de la compra."
            },
            email: {
              bsonType: "string",
              minLength: 3,
              description: "Correo electronico de contacto del cliente."
            }
          }
        },
        lineas: {
          bsonType: "array",
          minItems: 1,
          description: "Arreglo no vacio de renglones del pedido (minimo 1 item).",
          items: {
            bsonType: "object",
            required: [
              "id_producto",
              "nombre_producto",
              "categoria",
              "cantidad",
              "precio_unitario",
              "subtotal"
            ],
            properties: {
              id_producto: {
                bsonType: ["int", "long"],
                minimum: 1,
                description: "Identificador del producto."
              },
              nombre_producto: {
                bsonType: "string",
                minLength: 1,
                description: "Nombre del producto."
              },
              categoria: {
                bsonType: "string",
                minLength: 1,
                description: "Nombre de la categoria desnormalizada."
              },
              cantidad: {
                bsonType: ["int", "long"],
                minimum: 1,
                description: "Cantidad vendida estrictamente positiva (> 0)."
              },
              precio_unitario: {
                bsonType: "decimal",
                description: "Precio unitario historico pactado en BSON Decimal128 (NumberDecimal)."
              },
              subtotal: {
                bsonType: "decimal",
                description: "Subtotal de la linea (cantidad * precio_unitario) en BSON Decimal128."
              }
            }
          }
        },
        total_pedido: {
          bsonType: "decimal",
          description: "Importe total del pedido en BSON Decimal128 (NumberDecimal)."
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

print(" >>> CREACIÓN DE COLECCIÓN 'pedidos' CON VALIDADOR $jsonSchema:");
printjson(resultadoCreacionColeccion);
print("");

// 3. Inserción de los 6 pedidos reales migrados desde PostgreSQL
// Todos los importes monetarios (precio_unitario, subtotal, total_pedido) se
// almacenan como NumberDecimal("...") (tipo BSON Decimal128) para preservar
// precisión decimal exacta de base 10 equivalente a NUMERIC(10,2) en PostgreSQL.
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
        precio_unitario: NumberDecimal("1050.00"),
        subtotal: NumberDecimal("2100.00")
      },
      {
        id_producto: 3,
        nombre_producto: "Coca 1.5L",
        categoria: "Bebidas",
        cantidad: 1,
        precio_unitario: NumberDecimal("800.00"),
        subtotal: NumberDecimal("800.00")
      },
      {
        id_producto: 6,
        nombre_producto: "Producto FoodStore 1",
        categoria: "Almacén",
        cantidad: 2,
        precio_unitario: NumberDecimal("3113.43"),
        subtotal: NumberDecimal("6226.86")
      },
      {
        id_producto: 7,
        nombre_producto: "Producto FoodStore 2",
        categoria: "Postres",
        cantidad: 2,
        precio_unitario: NumberDecimal("4338.74"),
        subtotal: NumberDecimal("8677.48")
      }
    ],
    total_pedido: NumberDecimal("17804.34")
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
        precio_unitario: NumberDecimal("1500.00"),
        subtotal: NumberDecimal("1500.00")
      },
      {
        id_producto: 8,
        nombre_producto: "Producto FoodStore 3",
        categoria: "Postres",
        cantidad: 2,
        precio_unitario: NumberDecimal("2245.58"),
        subtotal: NumberDecimal("4491.16")
      },
      {
        id_producto: 9,
        nombre_producto: "Producto FoodStore 4",
        categoria: "Bebidas",
        cantidad: 3,
        precio_unitario: NumberDecimal("3890.33"),
        subtotal: NumberDecimal("11670.99")
      }
    ],
    total_pedido: NumberDecimal("17662.15")
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
        precio_unitario: NumberDecimal("1500.00"),
        subtotal: NumberDecimal("3000.00")
      },
      {
        id_producto: 3,
        nombre_producto: "Coca 1.5L",
        categoria: "Bebidas",
        cantidad: 4,
        precio_unitario: NumberDecimal("800.00"),
        subtotal: NumberDecimal("3200.00")
      },
      {
        id_producto: 10,
        nombre_producto: "Producto FoodStore 5",
        categoria: "Limpieza",
        cantidad: 2,
        precio_unitario: NumberDecimal("1926.54"),
        subtotal: NumberDecimal("3853.08")
      },
      {
        id_producto: 11,
        nombre_producto: "Producto FoodStore 6",
        categoria: "Carnicería y Granja",
        cantidad: 2,
        precio_unitario: NumberDecimal("1243.15"),
        subtotal: NumberDecimal("2486.30")
      }
    ],
    total_pedido: NumberDecimal("12539.38")
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
        precio_unitario: NumberDecimal("811.44"),
        subtotal: NumberDecimal("811.44")
      },
      {
        id_producto: 13,
        nombre_producto: "Producto FoodStore 8",
        categoria: "Congelados",
        cantidad: 2,
        precio_unitario: NumberDecimal("1182.13"),
        subtotal: NumberDecimal("2364.26")
      }
    ],
    total_pedido: NumberDecimal("3175.70")
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
        precio_unitario: NumberDecimal("3095.70"),
        subtotal: NumberDecimal("12382.80")
      },
      {
        id_producto: 15,
        nombre_producto: "Producto FoodStore 10",
        categoria: "Panificados",
        cantidad: 4,
        precio_unitario: NumberDecimal("3180.31"),
        subtotal: NumberDecimal("12721.24")
      }
    ],
    total_pedido: NumberDecimal("25104.04")
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
        precio_unitario: NumberDecimal("3284.84"),
        subtotal: NumberDecimal("13139.36")
      },
      {
        id_producto: 17,
        nombre_producto: "Producto FoodStore 12",
        categoria: "Congelados",
        cantidad: 4,
        precio_unitario: NumberDecimal("2790.12"),
        subtotal: NumberDecimal("11160.48")
      }
    ],
    total_pedido: NumberDecimal("24299.84")
  }
];

const resultadoInsercion = db.pedidos.insertMany(pedidosMigrados);
print(" >>> EVIDENCIA DE INSERCIÓN (insertMany con Decimal128):");
printjson(resultadoInsercion);
print(` >>> Total documentos insertados: ${Object.keys(resultadoInsercion.insertedIds).length}\n`);

// 4. Prueba de validación del esquema ($jsonSchema): rechazo de documento con double
print("============================================================================");
print(" PRUEBA DE VALIDADOR $jsonSchema: Intento de inserción con importe en double");
print("============================================================================");
try {
  db.pedidos.insertOne({
    id_pedido: 999,
    fecha_hora: ISODate("2026-10-01T10:00:00Z"),
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
        cantidad: 1,
        precio_unitario: 1050.50, // ERROR INTENCIONAL: double en lugar de Decimal128
        subtotal: 1050.50         // ERROR INTENCIONAL: double en lugar de Decimal128
      }
    ],
    total_pedido: 1050.50         // ERROR INTENCIONAL: double en lugar de Decimal128
  });
} catch (err) {
  print(" >>> RECHAZO ESPERADO DEL MOTOR MONGODB (Document failed validation):");
  print("Codigo de error: " + err.code + " (" + err.codeName + ")");
  print("Mensaje: " + err.message);
  printjson(err.errInfo);
}
print("");

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
print(" Criterio: total_pedido > NumberDecimal('15000.00') (Pedidos de Alto Valor)");
print("============================================================================");
const consultaD = db.pedidos.find(
  { total_pedido: { $gt: NumberDecimal("15000.00") } },
  { id_pedido: 1, estado: 1, "cliente.nombre": 1, total_pedido: 1, _id: 0 }
).sort({ total_pedido: -1 }).toArray();

printjson(consultaD);
print(`Total recuperados consulta (d): ${consultaD.length}\n`);

print("============================================================================");
print(" LABORATORIO IA 1: Demostración de imprecisión IEEE 754 (double) vs Decimal128");
print("============================================================================");
const pruebaPrecision = db.pedidos.aggregate([
  { $limit: 1 },
  {
    $project: {
      _id: 0,
      suma_double_ieee754: { $add: [0.1, 0.2] },
      suma_decimal128_exacta: { $add: [NumberDecimal("0.10"), NumberDecimal("0.20")] },
      total_pedido_almacenado: "$total_pedido",
      tipo_bson_total: { $type: "$total_pedido" }
    }
  }
]).toArray();
printjson(pruebaPrecision);
print("");

print("============================================================================");
print(" LABORATORIO IA 2: Plan de ejecución explain('executionStats') por id_pedido");
print("============================================================================");
const planLecturaAgregado = db.pedidos.find({ id_pedido: 1 }).explain("executionStats");
printjson({
  queryPlanner: {
    winningPlan: planLecturaAgregado.queryPlanner.winningPlan
  },
  executionStats: {
    executionSuccess: planLecturaAgregado.executionStats.executionSuccess,
    nReturned: planLecturaAgregado.executionStats.nReturned,
    executionTimeMillis: planLecturaAgregado.executionStats.executionTimeMillis,
    totalKeysExamined: planLecturaAgregado.executionStats.totalKeysExamined,
    totalDocsExamined: planLecturaAgregado.executionStats.totalDocsExamined
  }
});
print("");

print("============================================================================");
print(" LABORATORIO IA 3: Pipeline de Agregación ($match + $unwind + $group + $sort)");
print(" Facturación y unidades por categoría en pedidos ENTREGADOS con Decimal128");
print("============================================================================");
const reporteCategorias = db.pedidos.aggregate([
  { $match: { estado: "ENTREGADO", eliminado: false } },
  { $unwind: "$lineas" },
  {
    $group: {
      _id: "$lineas.categoria",
      cantidad_lineas: { $sum: 1 },
      unidades_vendidas: { $sum: "$lineas.cantidad" },
      facturacion_categoria: { $sum: "$lineas.subtotal" }
    }
  },
  { $sort: { facturacion_categoria: -1 } }
]).toArray();

printjson(reporteCategorias);
