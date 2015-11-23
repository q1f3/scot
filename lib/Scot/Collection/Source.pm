package Scot::Collection::Source;
use lib '../../../lib';
use Moose 2;
extends 'Scot::Collection';
with    qw(
    Scot::Role::GetByAttr
    Scot::Role::GetTagged
);

# source creation or update
sub create_from_handler {
    my $self    = shift;
    my $handler = shift;
    my $env     = $handler->env;
    my $log     = $env->log;

    $log->trace("Custom create in Scot::Collection::Source");

    my $build_href  = $handler->get_request_params->{params};
    my $target_type = $build_href->{target_type};
    my $target_id   = $build_href->{target_id};
    my $value        = $build_href->{value};

    unless ( defined $target_type ) {
        $log->error("Error: must provide a target type");
        return { error_msg => "Sources must have a target_type defined"};
    }

    unless ( defined $target_id ) {
        $log->error("Error: must provide a target id");
        return { error_msg => "Sources must have a target_id defined"};
    }

    unless ( defined $value ) {
        $log->error("Error: must provide the source as the value param");
        return { error_msg => "No Source value provided" };
    }

    my $source_collection  = $handler->env->mongo->collection("Source");
    my $source_obj         = $source_collection->find_one({ value => $value });

    unless ( defined $source_obj ) {
        $source_obj    = $source_collection->create({
            value    => $value,
            targets => [{
                type    => $target_type,
                id      => $target_id,
            }],
        });
    }
    else {
        $source_obj->update_add( targets => {
            type    => $target_type,
            id      => $target_id,
        });
    }

    $env->mongo->collection("History")->add_history_entry({
        who     => "api",
        what    => "source created for $target_type : $target_id",
        when    => $env->now,
        targets => [ { id => $source_obj->id, type => "source" } ],
    });

    return $source_obj;

}

sub get_sources {
    my $self    = shift;
    my %params  = @_;

    my $id      = $params{target_id} + 0;
    my $thing   = $params{target_type};

    my $cursor  = $self->find({
        targets => {
            '$elemMatch' => {
                type => $thing,
                id   => $id,
            },
        },
    });
    my $count   = $cursor->count;
    return $cursor;
}

sub get_source_completion { 
    my $self    = shift;
    my $string  = shift;
    my @results = ();
    my $cursor  = $self->find({
        value    => /$string/
    });
    @results    = map { $_->value } $cursor->all;
    return wantarray ? @results : \@results;
}

sub add_source_to {
    my $self    = shift;
    my $handler = shift;
    my $thing   = shift;
    my $id      = shift;
    my $source  = shift;

    my $env = $handler->env;

    my $source_obj         = $self->find_one({ value => $source });
    unless ( defined $source_obj ) {
        $source_obj    = $self->create({
            value    => $source,
            targets => [{
                type    => $thing,
                id      => $id,
            }],
        });
    }
    else {
        $source_obj->update_add( targets => {
            type    => $thing,
            id      => $id,
        });
    }

    $env->mongo->collection("History")->add_history_entry({
        who     => "api",
        what    => "source cite added $thing : $id",
        when    => $env->now,
        targets => [ { id => $source_obj->id, type => "source" } ],
    });


    return $source_obj;
}


1;
