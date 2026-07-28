// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://gilsonbs.github.io',
  // A barra final é obrigatória: o código monta URLs concatenando
  // `${import.meta.env.BASE_URL}admin/`. Sem ela, BASE_URL vira
  // "/gestao-equipe" e os links saem grudados ("/gestao-equipeadmin/").
  base: '/gestao-equipe/',
  output: 'static',
});

