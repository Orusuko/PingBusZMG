import axios from 'axios'

const client = axios.create({ baseURL: '/api' })

export interface Ruta {
  clave: string
  nombre: string
  tipo: string
}

export interface ParadaETA {
  nombre: string
  distancia_m: number
  eta_minutos: number
}

export interface UnidadDetectada {
  unidad_id: number
  posicion: { lat: number; lon: number }
  confianza: number
  ultima_actualizacion: string | null
  proximas_paradas: ParadaETA[]
}

export interface ConsultaResponse {
  ruta: string
  unidades: UnidadDetectada[]
  total: number
}

export interface RutaEstadistica {
  clave: string
  pings_activos: number
  unidades_detectadas: number
}

export interface EstadisticasResponse {
  pings_activos_total: number
  ventana_minutos: number
  rutas: RutaEstadistica[]
}

export interface Parada {
  nombre: string
  orden: number
  lat: number
  lon: number
}

export interface TrazadoResponse {
  clave: string
  nombre: string
  tipo: string
  trazado: { type: string; coordinates: [number, number][] } | null
  paradas: Parada[]
}

export const api = {
  getRutas: () => client.get<Ruta[]>('/rutas').then(r => r.data),
  consultarRuta: (clave: string) =>
    client.get<ConsultaResponse>(`/consultar/${clave}`).then(r => r.data),
  getTrazado: (clave: string) =>
    client.get<TrazadoResponse>(`/rutas/${clave}/trazado`).then(r => r.data),
  reportar: (uuid: string, ruta: string, lat: number, lon: number) =>
    client.post('/reportar', { uuid, ruta, lat, lon }).then(r => r.data),
  getEstadisticas: () =>
    client.get<EstadisticasResponse>('/estadisticas').then(r => r.data),
  getHealth: () =>
    client.get<{ status: string; postgis: string }>('/health').then(r => r.data),
}
