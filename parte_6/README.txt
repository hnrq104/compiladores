Disciplina: Compiladores
Professor: Hugo Musso
Aluno: Henrique Lima Cardoso (baiano)

Para gerar código de máquina, redirecione um arquivo de entrada para o STDIN de compila.lua e
redirecione a saída (STDOUT) para outro arquivo - onde deseja salvar o bytecode.
> $ lua compila.lua < teste.lua > out.lbyte
(eu uso lbyte para diferenciar quando foi compilado usando lua ou vm.lua - que uso só byte)

Para usar a máquina virtual passe o bytecode como primeiro argumento de vm.lua.
> $ lua vm.lua out.lbyte

Fiquei muito feliz que consegui autocompilar!
Esperava que ia ser muito mais fácil, depois que terminei de fazer closure e locais realmente acreditei que já
estava quase tudo pronto. Como me enganei, implementar o for loop e break foi tranquilo, o problema eram todos os bugs
que surgiram nas 3 mil linhas de código. Cada problema que aparecia surgia a dúvida, é problema da vm, do código do compilador
ou do bytecode gerado pelo compilador. Foi um trabalho árduo, mas foi recompensador.

Obs: Para a autocompilação, podemos rodar a seguinte sequência:
1: > $ lua compila.lua < compila.lua > c.lbyte
2: > $ lua vm.lua c.lbyte < compila.lua > c.byte
(essa etapa é o bootstrap)
3: > diff c.lbyte c.byte

Uma coisa interessante acontece aqui, por conta da ordem de execução da avaliação de valores
dos sets múltiplos, haverão diferenças entre a ordem das labels do código. Mas além disso, está tudo certo :)
Uma forma de ver é fazer mais uma etapa do bootstrapping.

4: > $ lua vm.lua c.byte < compila.lua > c2.byte
5: > $ diff c.byte c2.byte


-- Mudanças do trabalho 5 para o trabalho 6.
Implementação de Variaveis Locais e Closure:

Variaveis Locais:
    Fiz uma lista de listas linkadas no compilador para manter os ambientes e níveis de funções
    como idealizado em aula. A nivel de vm, os ambientes são também uma lista linkada de funções por nivel,
    cada nó de função tem uma array das variáveis locais. Como não usei funções aninhadas, a profundidade máxima
    foi 1.

Closure:
    Diferente do sugerido na implementação, meus ValLuaFunc's não contém as instruções em si,
    somente um ponteiro para a função que será executada. A VM guarda todas as funções em uma lista de execução.
    Temos quantidade variada de argumentos e retornos (vou abordar isso um pouco mais abaixo).

    A nível de compilação, para não ter que adicionar um argumento a mais em cada função de geração,
    fiz uma maquininha global 'CODE', que guarda num stack em que função estamos escrevendo. Basta lembrar que
    ao gerar o código de uma função darmos pushfunctionstack, e, depois da geração, popfunctionstack.
    O mesmo foi feito para o break, por preguiça. (Acho no entanto que facilitou bem).

Sets, Argumentos e Retornos múltiplos:
    Há uma diferença fundamental para sets, argumentos e retornos. Para o set sabemos exatamente
    quantos valores precisamos. Para argumentos, sabemos exatamente quantos argumentos estamos mandando.
    Para retornos sabemos "talvez" quantas coisas deveriamos retornar. Vamos passo a passo.

    Para set múltiplo, o compilador chama genCodeExp esperando 1 valor de retorno para cada variável,
    se o último valor foi uma call, então ele chama a call esperando a quantidade de valores faltando.

    Resolvi o problema de set de tabelas criando um LVALUE, acessível somente a VM. Acho que foi a maneira mais fácil,
    fizemos isso criando conjuntamente uma instrução nova SETLIST.

    Para argumentos e retornos adicionei um valor de runtime novo ValReturnList. Esse valor só é usado e necessário
    exatamente nas condições onde NÃO sabemos quantos valores serão retornados por uma função. Os dois exemplos são
    e são invocados da forma CALL (N_ARGS) -1, onde -1 entende-se por (quantidade variada de retornos):

    - f(1,g())
    - return 2,3,h()

    A questão fundamental é que num nível anterior, sempre sabemos quantos argumentos estamos precisando originalmente,
    delegamos essa decisão até a função chamadora que pediu uma quantidade fixa de argumentos. Ela tem o papel de que
    se receber um VALRETLIST, entrar nele e limpá-lo (isso é transforma-lo numa lista de valores básicos)

For Loops:
    Fiz bem bobão, basta olhar a implementação de genFor em compila.lua; Escrevi uma expressão grandona condicional
    e usei o genJmp implementado antes.

Bugs:
    Nem sei quantas coisinhas tive que consertar no caminho, lidar com funções globais que havia esquecido de colocar. Tinha um erro no if-else
    repassar pelo código inteiro limpando para saber o que havia implementado ou não. Consertar o io.read(). Tratar do problema do GSUB,
    todas as #str que tinham no caminho.

    São todas coisas relativamente tranquilas, mas faltou-me astúcia e diligência para uma única mudança radical necessária para esse trabalho.
    ESCREVER DE QUE LINHA DO CÓDIGO A INSTRUÇÃO ESTÁ VINDO. Isso é fundamental e peço encarecidademente que peça para seus futuros alunos
    não se esquecerem disso. Ia facilitar minha vida consideravelmente.

Etapas felizes:
Quando rodei o compilador nele mesmo pela primeira vez óbviamente não funcionou, toda hora um problema distinto aparecia.
Decidi então tentar compilar somente o lexer. Claro que não funcionou também, mas de grão em grão fui resolvendo os problemas um por um.
Quando eu finalmente conseguir compilar o lexer e rodar o MEU lexer nele mesmo, foi fantástico, dormi feliz ontem!

Hoje a sensação foi bem parecida resolvendo os problemas do compilação um a um e honestamente, quando a autocompilação aconteceu foi uma surpresa!
Exclamei: Chegou o grande meio dia!
Bastava agora botá-lo para funcionar e é óbvio que não funcionou. Voltei a mão de obra de resolver, dessa vez problemas na VM.
Nenhuma ideia de implementação estava errada, eram realmente só bobagem, mas foi indo.

É isso, muita felicidade.
Um abração e boas férias!

Henrique
