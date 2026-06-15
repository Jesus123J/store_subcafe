package com.thiago.gestionbodega.modules.vales.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import com.thiago.gestionbodega.modules.clientes.repository.ClienteRepository;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import com.thiago.gestionbodega.modules.vales.dto.EmitirValeRequest;
import com.thiago.gestionbodega.modules.vales.dto.ValeDto;
import com.thiago.gestionbodega.modules.vales.entity.EstadoVale;
import com.thiago.gestionbodega.modules.vales.entity.TipoVale;
import com.thiago.gestionbodega.modules.vales.entity.Vale;
import com.thiago.gestionbodega.modules.vales.repository.ValeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ValeService {

    private final ValeRepository repo;
    private final ClienteRepository clienteRepo;
    private final UsuarioRepository usuarioRepo;

    public List<ValeDto> listar(EstadoVale estado) {
        var lista = estado != null
                ? repo.findByEstadoOrderByFechaEmisionDesc(estado)
                : repo.findAll();
        return lista.stream().map(ValeDto::from).toList();
    }

    @Transactional
    public ValeDto emitir(String username, EmitirValeRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Cliente cliente = null;
        if (req.tipo() == TipoVale.NOMBRADO) {
            if (req.clienteId() == null) {
                throw new BusinessException(
                    "Vale NOMBRADO requiere un cliente. Use tipo=CASH para al portador.");
            }
            cliente = clienteRepo.findById(req.clienteId())
                    .orElseThrow(() -> new NotFoundException("Cliente no encontrado"));
        }

        String codigo = generarCodigo();
        Vale v = Vale.builder()
                .codigo(codigo)
                .tipo(req.tipo())
                .cliente(cliente)
                .montoInicial(req.monto())
                .saldo(req.monto())
                .estado(EstadoVale.ACTIVO)
                .fechaEmision(OffsetDateTime.now())
                .fechaVencimiento(req.fechaVencimiento())
                .emitidoPor(user)
                .observaciones(req.observaciones())
                .build();
        return ValeDto.from(repo.save(v));
    }

    @Transactional
    public ValeDto anular(java.util.UUID id) {
        Vale v = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Vale no encontrado"));
        if (v.getEstado() == EstadoVale.CONSUMIDO) {
            throw new BusinessException("No se puede anular un vale ya consumido");
        }
        v.setEstado(EstadoVale.ANULADO);
        return ValeDto.from(repo.save(v));
    }

    private String generarCodigo() {
        int year = OffsetDateTime.now().getYear();
        long count = repo.count() + 1;
        return String.format("V-%d-%06d", year, count);
    }
}
