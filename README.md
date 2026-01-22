# 🤝 Customer Success Analytics: Dashboard de Health Score e Retenção

![Status](https://img.shields.io/badge/Status-Concluído-success)
![Área](https://img.shields.io/badge/Foco-Customer_Success_%26_Retention-orange)
![Ferramenta](https://img.shields.io/badge/Power_BI-Desktop-yellow)

> **[🔗 CLIQUE AQUI PARA VER O DASHBOARD INTERATIVO](COLOQUE_SEU_LINK_AQUI)**

## 💼 O Desafio de Negócio
Para uma empresa baseada em recorrência (assinatura/SaaS), a retenção de clientes é tão importante quanto a venda. O objetivo deste projeto foi centralizar os dados de comportamento dos clientes para identificar contas em risco de cancelamento (**Churn**) antes que ele aconteça.

**Perguntas-chave:**
1. Quais clientes estão com a "Saúde" baixa (Risco de Churn)?
2. Como está a evolução do NPS (Satisfação) por segmento de cliente?
3. Qual é a taxa de engajamento da base ativa?

---

## 🛠️ A Solução: Algoritmo de Health Score

O diferencial deste projeto foi o desenvolvimento de um **Health Score** (Pontuação de Saúde) calculado via DAX. A métrica não é apenas um número, mas uma média ponderada de três pilares fundamentais:

* **Engajamento (40%):** Frequência de login e uso das ferramentas principais.
* **Suporte (30%):** Volume de tickets abertos e tempo de resolução.
* **Financeiro (30%):** Histórico de pagamentos e inadimplência.

### Lógica Técnica (DAX)
Utilizei a função `SWITCH` e variáveis (`VAR`) para normalizar diferentes escalas (ex: dias sem acesso vs. número de tickets) em uma nota única de 0 a 100.

```dax
Health Score = 
VAR Nota_Uso = [Média Acessos] * 0.4
VAR Nota_Suporte = [Score Tickets] * 0.3
VAR Nota_Financeiro = [Score Pagamentos] * 0.3
RETURN
Nota_Uso + Nota_Suporte + Nota_Financeiro
