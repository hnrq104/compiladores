Disciplina: Compiladores
Professor: Hugo Musso
Aluno: Henrique Lima Cardoso (baiano)

Para gerar código de máquina do trabalho 5, redirecione um arquivo de entrada para o STDIN de compila.lua e 
redirecione a saída (STDOUT) para outro arquivo - onde deseja salvar o bytecode.
> $ lua compila.lua < teste.lua > out.luac

Para usar a máquina virtual, redirecione o bytecode para o STDIN de vm.lua.
> $ lua vm.lua < out.luac

-- MUDANÇAS NA LINGUAGEM DE MÁQUINA

Adicionei as seguintes instruções:
DUP (n): Duplica n vezes o que está no topo da pilha. Isso só foi utilizado para construir tabelas.
JUMP_TRUE_OR_POP (label): Como determinado em aula, faz o jump se for verdade sem consumir o topo da pilha, se não consome.
JUMP_FALSE_OR_POP (label):           //                    //         "falso"       //               //           //    

-- OBSERVAÇÕES SOBRE ESSE TRABALHO
- abstract: NÃO ESTÁ PERTO DE SER IDEAL >:(

O que falta fazer (talvez em ordem de importância):

(1) Fazer label e instruction corretamente.

    Da forma que está, as instruções e argumentos não estão corretamente tipadas e tageadas (usando fortemente 
    gambiarra de tipagem dinâmica). Os labels não devem ser calculados em tempo de execução, devemos repassar por todas 
    as instruções de jump (e no prox trabalho de call) para que as labels se tornem de fato números (estou usando 
    uma hash_table [string][num] para isso). Isso é chatinho mas é bem fácil de resolver: basta 
    deixar makeinst mais robusta e, depois de read_program(), fazer um assemble_program() - para substituir as labels.
    (Isso fazia parte da nota desse trabalho 5 e não está entregue de maneira decente)


(2) Coisas do próximo trabalho: ambiente, closure, comando local, stacks de funções.

    Não ponhemos a carroça na frente dos bois. Descubriremos o futuro que nos espera eventualmente; 
    (Não foi determinado o que fazer ainda)


(3) Consertar genJmp.

    Consegui fazer uma geração de código para expressões (or) e (and) bem legalzinha. No entanto, deve 
    haver uma pequena mudança para geração do genJmp, atualmente ele basicamente faz:
        genCodeExp(exp, nil, nil)
        if lbl_t then
            JUMP_TRUE(lbl_t)
        else
            JUMP_FALSE(lbl_f)
        end
    O que é meio estúpido se exp for uma or e and. Tem um jump a mais completamente desnecessário.

(4) Implementar for loop e break (importante para autocompilação).

(5) Repassar compila.lua para que use somente um subset de lua que implementamos. Isso envolve 
basicamente apagar o uso de funções de biblioteca variádicas, e implementar loop e break. (tirar uso de string.gsub)

(6) Tratamento de erro para o bytecode. Vai que um maluco quer escrever em assembly.

-- Opcional
Acho que vm.lua está mal organizado e que o estilo de programação está diferente de compila.lua, talvez rever isso.